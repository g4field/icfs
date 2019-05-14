#
# Investigative Case File System
#
# Copyright 2019 by Graham A. Field
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'set'
require 'json'
require 'tempfile'

module ICFS

##########################################################################
# Object validation
#
# @todo Move .parse and .generate to items or ICFS
# @todo Remove all use of Error module
# @todo Switch to use Is* (e.g. IsBoolean) rather than Val*
#
module Validate


  ###############################################
  # Parse JSON string and validate
  #
  # @param json [String] the JSON to parse
  # @param name [String] description of the item
  # @param val [Hash] the check to use
  # @return [Object] the item
  #
  # @raise [Error::NotFound] if json is nil
  # @raise [Error::Value] if parsing or validation fails
  #
  def self.parse(json, name, val)
    if json.nil?
      raise(Error::NotFound, '%s not found'.freeze % name)
    end
    begin
      itm = JSON.parse(json)
    rescue
      raise(Error::Value, 'JSON parsing failed'.freeze)
    end
    Validate.validate(itm, name, val)
    return itm
  end # def self.parse()


  ###############################################
  # Validate and generate JSON
  #
  # @param itm [Object] item to validate
  # @param name [String] description of the item
  # @param val [Hash] the check to use
  # @return [String] JSON encoded item
  #
  # @raise [Error::Value] if validation fails
  #
  def self.generate(itm, name, val)
    Validate.validate(itm, name, val)
    return JSON.pretty_generate(itm)
  end # def self.generate()


  ###############################################
  # Validate an object
  #
  # @param obj [Object] object to validate
  # @param name [String] description of the object
  # @param val [Hash] the check to use
  #
  # @raise [Error::Value] if validation fails
  #
  def self.validate(obj, name, val)
    err = Validate.check(obj, val)
    if err
      raise(Error::Value, '%s has bad values: %s'.freeze %
        [name, err.inspect])
    end
  end


  ###############################################
  # check an object
  #
  # @param obj [Object] object to validate
  # @param val [Hash] the check to use
  # @return [Object] error description
  #
  def self.check(obj, val)
    if val.key?(:object)
      err = val[:object].send(val[:method], obj, val)
    else
      err = Validate.send(val[:method], obj, val)
    end
    return err
  end # def self.check()


  ##############################################################
  # Check Methods
  ##############################################################


  ###############################################
  # check that any one validation is good
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Array<Hash>] :check validations to check
  # @return [Array,NilClass] error descriptions
  #
  def self.any(obj, val)
    return nil unless val[:check].is_a?(Array)

    errors = []

    val[:check].each do |chk|
      err = Validate.check(obj, chk)
      return nil if err.nil?
      errors << err
    end

    return errors
  end # def self.any()


  ###############################################
  # check that all the validations are good
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Array<Hash>] :check validations to check
  # @option val [Boolean] :all Always check all the validations
  # @return [Array, NilClass] error descriptions
  #
  def self.all(obj, val)
    return nil unless val[:check].is_a?(Array)

    errors = []
    bad = false

    val[:check].each do |check|
      err = Validate.check(obj, check)
      if err
        errors << err
        bad = true
        break unless val[:all]
      else
        errors << nil
      end
    end

    return bad ? errors : nil
  end # def self.all()


  ###############################################
  # Check for an exact value
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Integer] :check Value to compare
  # @return [String,NilClass] error descriptions
  #
  def self.equals(obj, val)
    if val[:check] == obj
      return nil
    else
      return 'not equal'.freeze
    end
  end # def self.equals()


  ###############################################
  # check an integer
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Integer] :min Minimum value
  # @option val [Integer] :max Maximum value
  # @return [String,NilClass] error descriptions
  #
  #
  def self.integer(obj, val)
    return 'not an Integer'.freeze unless obj.is_a?(Integer)

    if val[:min] && obj < val[:min]
      return 'too small: %d < %d'.freeze % [obj, val[:min]]
    end

    if val[:max] && obj > val[:max]
      return 'too large: %d > %d '.freeze % [obj, val[:max]]
    end

    return nil
  end # def self.integer()


  ###############################################
  # check a float
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Float] :min Minimum value
  # @option val [Float] :max Maximum value
  # @return [String,NilClass] error descriptions
  #
  def self.float(obj, val)
    return 'not a Float'.freeze unless obj.is_a?(Float)

    if val[:min] && obj < val[:min]
      return 'too small: %f < %f'.freeze % [obj, val[:min]]
    end

    if val[:max] && obj > val[:max]
      return 'too large: %f > %f'.freeze % [obj, val[:max]]
    end

    return nil
  end # def self.float()


  ###############################################
  # check for a type
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Class,Array] :type The class or module to check
  # @return [String,NilClass] error descriptions
  #
  def self.type(obj, val)
    if val[:type]
      if val[:type].is_a?(Array)
        val[:type].each{|cl| return nil if obj.is_a?(cl) }
        return 'not a listed type'.freeze
      else
        if !obj.is_a?(val[:type])
          return 'not a %s'.freeze % val[:type].name
        end
      end
    end
    return nil
  end # def self.type


  ###############################################
  # check a string
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [#include?] :allowed Value which is always okay
  # @option val [#match] :valid check for okay value
  # @option val [Boolean] :whitelist Must be valid or allowed
  # @option val [#match] :invalid check for bad values
  # @option val [Integer] :min Minimum length
  # @option val [Integer] :max Maximum length
  # @return [Hash,NilClass] error descriptions
  #
  def self.string(obj, val)

    # type
    return 'not a String'.freeze unless obj.is_a?(String)

    errors = {}

    # good values
    if (val[:allowed] && val[:allowed].include?(obj)) ||
       (val[:valid] && val[:valid].match(obj))
      return nil
    end

    # if whitelisting
    if val[:whitelist]
      errors[:whitelist] = 'Value was not whitelisted'.freeze
    end

    # min length
    if val[:min] && obj.size < val[:min]
      errors[:min] = 'too short: %d < %d' % [obj.size, val[:min]]
    end

    # max length
    if val[:max] && obj.size > val[:max]
      errors[:max] = 'too long: %d > %d' % [obj.size, val[:max]]
    end

    # invalid
    if val[:invalid] && val[:invalid].match(obj)
      errors[:invalid] = true
    end

    return errors.empty? ? nil : errors
  end # def self.string()


  ###############################################
  # check an array
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Integer] :min Minimum length
  # @option val [Integer] :max Maximum length
  # @option val [TrueClass] :uniq Require all members to be unique
  # @option val [Hash,Array] :check Validations for members of the array.
  #    If a Hash is provided, all members will be checked against it.
  #    If an Array is provided, they will be checked in order.
  # @return [Hash,NilClass] error descriptions
  #
  def self.array(obj, val)

    # type
    return 'not an Array'.freeze unless obj.is_a?(Array)

    errors = {}

    # min size
    if val[:min] && obj.size < val[:min]
      errors[:min] = true
    end

    # max size
    if val[:max] && obj.size > val[:max]
      errors[:max] = true
    end

    # all members uniq
    if val[:uniq] && obj.size != obj.uniq.size
      errors[:uniq] = true
    end

    # single check, all items of the array
    if val[:check].is_a?(Hash)
      check = val[:check]

      # each value
      obj.each_index do |ix|
        if val[ix]
          err = Validate.check(obj[ix], val[ix])
        else
          err = Validate.check(obj[ix], check)
        end
        errors[ix] = err if err
      end

    # an array of checks
    elsif val[:check].is_a?(Array)
      cka = val[:check]
      cs = cka.size

      # each value
      obj.each_index do |ix|
        if val[ix]
          err = Validate.check(obj[ix], val[ix])
        else
          err = Validate.check(obj[ix], cka[ix % cs])
        end
        errors[ix] = err if err
      end
    end

    return errors.empty? ? nil : errors
  end # def self.array()


  ###############################################
  # check a hash
  #
  # @param obj [Object] object to validate
  # @param val [Hash] options
  # @option val [Hash] :required Keys which must be present and their checks
  # @option val [Hash] :optional Keys which may be present and their checks
  # @option val [TrueClass] :others Allow other keys
  # @return [Hash,NilClass] error descriptions
  #
  def self.hash(obj, val)

    # type
    return 'not a Hash'.freeze unless obj.is_a?(Hash)

    ary = obj.to_a
    chk = Array.new(ary.size)
    errors = {}

    # check all required keys
    if val[:required]
      val[:required].each do |key, check|

        # find the index
        ix = ary.index{|ok, ov| ok == key }

        # missing required key
        if ix.nil?
          errors[key] = 'missing'.freeze
          next
        end

        # check it
        err = Validate.check(ary[ix][1], check)
        errors[key] = err if err
        chk[ix] = true
      end
    end

    # check all optional keys
    if val[:optional]
      val[:optional].each do |key, check|

        # find the index
        ix = ary.index{|ok, ov| ok == key }
        next if ix.nil?

        # do the check
        err = Validate.check(ary[ix][1], check)
        errors[key] = err if err
        chk[ix] = true
      end
    end

    # make sure we have validated all keys
    if !val[:others]
      chk.each_index do |ix|
        next if chk[ix]
        errors[ary[ix][0]] = 'not allowed'.freeze
      end
    end

    # do we have any errors?
    return errors.empty? ? nil : errors

  end # def self.hash()


  ##############################################################
  # Common checks
  ##############################################################


  # Boolean
  ValBoolean = {
    method: :type,
    type: [ TrueClass, FalseClass ].freeze,
  }.freeze


  # Tempfile
  ValTempfile = {
    method: :type,
    type: Tempfile,
  }.freeze


  # Float
  ValFloat = {
    method: :type,
    type: [ Float ].freeze
  }.freeze


  # Positive Integer
  ValIntPos = {
    method: :integer,
    min: 1
  }.freeze


  # Unsigned Integer
  ValIntUns = {
    method: :integer,
    min: 0
  }.freeze


end # module ICFS::Validate

end # module ICFS
