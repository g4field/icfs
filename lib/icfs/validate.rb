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
# @todo Remove use of opts as its own hash
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
      err = val[:object].send(val[:method], obj, val[:opts])
    else
      err = Validate.send(val[:method], obj, val[:opts])
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
  # @param opt [Hash] options
  # @option opt [Array<Hash>] :check validations to check
  # @return [Array,NilClass] error descriptions
  #
  def self.any(obj, opt={})
    return nil unless opt[:check].is_a?(Array)

    errors = []

    opt[:check].each do |check|
      err = Validate.check(obj, check)
      return nil if err.nil?
      errors << err
    end

    return errors
  end # def self.any()


  ###############################################
  # check that all the validations are good
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [Array<Hash>] :check validations to check
  # @option opt [Boolean] :all Always check all the validations
  # @return [Array, NilClass] error descriptions
  #
  def self.all(obj, opt={})
    return nil unless opt[:check].is_a?(Array)

    errors = []
    bad = false

    opt[:check].each do |check|
      err = Validate.check(obj, check)
      if err
        errors << err
        bad = true
        break unless opt[:all]
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
  # @param opt [Hash] options
  # @option opt [Integer] :check Value to compare
  # @return [String,NilClass] error descriptions
  #
  def self.equals(obj, opt={})
    if opt[:check] == obj
      return nil
    else
      return 'not equal'.freeze
    end
  end # def self.equals()


  ###############################################
  # check an integer
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [Integer] :min Minimum value
  # @option opt [Integer] :max Maximum value
  # @return [String,NilClass] error descriptions
  #
  #
  def self.integer(obj, opt={})
    return 'not an Integer'.freeze unless obj.is_a?(Integer)

    if opt[:min] && obj < opt[:min]
      return 'too small: %d < %d'.freeze % [obj, opt[:min]]
    end

    if opt[:max] && obj > opt[:max]
      return 'too large: %d > %d '.freeze % [obj, opt[:max]]
    end

    return nil
  end # def self.integer()


  ###############################################
  # check a float
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [Float] :min Minimum value
  # @option opt [Float] :max Maximum value
  # @return [String,NilClass] error descriptions
  #
  def self.float(obj, opt={})
    return 'not a Float'.freeze unless obj.is_a?(Float)

    if opt[:min] && obj < opt[:min]
      return 'too small: %f < %f'.freeze % [obj, opt[:min]]
    end

    if opt[:max] && obj > opt[:max]
      return 'too large: %f > %f'.freeze % [obj, opt[:max]]
    end

    return nil
  end # def self.float()


  ###############################################
  # check for a type
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [Class,Array] :type The class or module to check
  # @return [String,NilClass] error descriptions
  #
  def self.type(obj, opt={})
    if opt[:type]
      if opt[:type].is_a?(Array)
        opt[:type].each{|cl| return nil if obj.is_a?(cl) }
        return 'not a listed type'.freeze
      else
        if !obj.is_a?(opt[:type])
          return 'not a %s'.freeze % opt[:type].name
        end
      end
    end
    return nil
  end # def self.type


  ###############################################
  # check a string
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [#include?] :allowed Value which is always okay
  # @option opt [#match] :valid check for okay value
  # @option opt [Boolean] :whitelist Must be valid or allowed
  # @option opt [#match] :invalid check for bad values
  # @option opt [Integer] :min Minimum length
  # @option opt [Integer] :max Maximum length
  # @return [Hash,NilClass] error descriptions
  #
  def self.string(obj, opt={})

    # type
    return 'not a String'.freeze unless obj.is_a?(String)

    errors = {}

    # good values
    if (opt[:allowed] && opt[:allowed].include?(obj)) ||
       (opt[:valid] && opt[:valid].match(obj))
      return nil
    end

    # if whitelisting
    if opt[:whitelist]
      errors[:whitelist] = 'Value was not whitelisted'.freeze
    end

    # min length
    if opt[:min] && obj.size < opt[:min]
      errors[:min] = 'too short: %d < %d' % [obj.size, opt[:min]]
    end

    # max length
    if opt[:max] && obj.size > opt[:max]
      errors[:max] = 'too long: %d > %d' % [obj.size, opt[:max]]
    end

    # invalid
    if opt[:invalid] && opt[:invalid].match(obj)
      errors[:invalid] = true
    end

    return errors.empty? ? nil : errors
  end # def self.string()


  ###############################################
  # check an array
  #
  # @param obj [Object] object to validate
  # @param opt [Hash] options
  # @option opt [Integer] :min Minimum length
  # @option opt [Integer] :max Maximum length
  # @option opt [TrueClass] :uniq Require all members to be unique
  # @option opt [Hash,Array] :check Validations for members of the array.
  #    If a Hash is provided, all members will be checked against it.
  #    If an Array is provided, they will be checked in order.
  # @return [Hash,NilClass] error descriptions
  #
  def self.array(obj, opt={})

    # type
    return 'not an Array'.freeze unless obj.is_a?(Array)

    errors = {}

    # min size
    if opt[:min] && obj.size < opt[:min]
      errors[:min] = true
    end

    # max size
    if opt[:max] && obj.size > opt[:max]
      errors[:max] = true
    end

    # all members uniq
    if opt[:uniq] && obj.size != obj.uniq.size
      errors[:uniq] = true
    end

    # single check, all items of the array
    if opt[:check].is_a?(Hash)
      check = opt[:check]

      # each value
      obj.each_index do |ix|
        if opt[ix]
          err = Validate.check(obj[ix], opt[ix])
        else
          err = Validate.check(obj[ix], check)
        end
        errors[ix] = err if err
      end

    # an array of checks
    elsif opt[:check].is_a?(Array)
      cka = opt[:check]
      cs = cka.size

      # each value
      obj.each_index do |ix|
        if opt[ix]
          err = Validate.check(obj[ix], opt[ix])
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
  # @param opt [Hash] options
  # @option opt [Hash] :required Keys which must be present and their checks
  # @option opt [Hash] :optional Keys which may be present and their checks
  # @option opt [TrueClass] :others Allow other keys
  # @return [Hash,NilClass] error descriptions
  #
  #
  def self.hash(obj, opt={})

    # type
    return 'not a Hash'.freeze unless obj.is_a?(Hash)

    ary = obj.to_a
    val = Array.new(ary.size)
    errors = {}

    # check all required keys
    if opt[:required]
      opt[:required].each do |key, check|

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
        val[ix] = true
      end
    end

    # check all optional keys
    if opt[:optional]
      opt[:optional].each do |key, check|

        # find the index
        ix = ary.index{|ok, ov| ok == key }
        next if ix.nil?

        # do the check
        err = Validate.check(ary[ix][1], check)
        errors[key] = err if err
        val[ix] = true
      end
    end

    # make sure we have validated all keys
    if !opt[:others]
      val.each_index do |ix|
        next if val[ix]
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
    opts: {
      type: [ TrueClass, FalseClass ].freeze,
    }.freeze
  }.freeze


  # Tempfile
  ValTempfile = {
    method: :type,
    opts: {
      type: Tempfile,
    }.freeze
  }.freeze


  # Float
  ValFloat = {
    method: :type,
    opts: {
      type: [ Float ].freeze
    }.freeze
  }.freeze


  # Positive Integer
  ValIntPos = {
    method: :integer,
    opts: {
      min: 1
    }.freeze
  }.freeze


  # Unsigned Integer
  ValIntUns = {
    method: :integer,
    opts: {
      min: 0
    }.freeze
  }.freeze


end # module ICFS::Validate

end # module ICFS
