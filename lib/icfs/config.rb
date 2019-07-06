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

# frozen_string_literal: true

require 'set'

module ICFS

##########################################################################
# Configuration storage interface
#
# @abstract
#
class Config

  # Default setup for 'tz'
  SetupTimezone = {
    name: 'Timezone',
    default: '+00:00',
    validate: {
      method: :string,
      valid: /[+\-](0[0-9]|1[0-2]):[0-5][0-9]/.freeze,
      whitelist: true,
    }.freeze,
    label: 'cfg-tz',
    input: [:text, 'form-tz'].freeze,
    parse: :text,
    tip: 'Timezone to display date/times, format as +/-HH:MM.',
    display: 'list-text-m',
  }.freeze


  # default setup for 'rel_time'
  SetupRelTime = {
    name: 'Rel. Time',
    default: true,
    validate: Validate::IsBoolean,
    label: 'cfg-reltime',
    input: [:boolean].freeze,
    parse: :boolean,
    tip: 'Display relative times e.g. 3 days ago.',
    display: 'list-text-s',
  }.freeze


  # default setup for 'css'
  SetupCss = {
    name: 'Style',
    default: '/static/icfs.css',
    validate: {
      method: :string,
      allowed: Set[
        '/static/icfs.css',
        '/static/icfs-dark.css'
      ].freeze,
      whitelist: true,
    }.freeze,
    label: 'cfg-css',
    input: [
      :select,
      'form-css',
      'cfg-css',
      [
        ['/static/icfs.css', 'Light'].freeze,
        ['/static/icfs-dark.css', 'Dark'].freeze,
      ].freeze
    ].freeze,
    parse: :text,
    tip: 'Display settings for web interface.',
    display: 'list-text-l',
  }.freeze


  ###############################################
  # New instance
  #
  # @param setup [Array<Array>] The setup array
  #
  # Each item is a \[key, hash\], each hash should contain:
  # - :name The name of the config setting
  # - :default The default value
  # - :validate A Validator
  # - :label The HTML label
  # - :input Array used by {Web::Client#_form_config}
  # - :parse
  # - :tip Text of the tup
  # - :display Array to pass to {Web::Client#_div_config}
  #
  def initialize(setup)
    @data = {}
    @unam = nil
    @order = []
    @setup = {}
    setup.each do |ary|
      @order << ary[0]
      @setup[ary[0]] = ary[1]
    end
  end # def initialize()


  ###############################################
  # Clear data
  def clear; @data = {}; end


  ###############################################
  # The configuration values hash
  #
  attr_accessor :data


  ###############################################
  # The configuration defaults
  #
  attr_reader :defaults


  ###############################################
  # Get the option for this key
  #
  def _opt(key)
    opt = @setup[key]
    raise(ArgumentError, 'Invalid config option') unless opt
    return opt
  end # def _opt()
  private :_opt


  ###############################################
  # Get a value
  #
  # @param key [String] The name of the config setting
  #
  def get(key)
    opt = _opt(key)
    @data.key?(key) ? @data[key] : opt[:default]
  end


  ###############################################
  # Set a value
  #
  # @param key [String] The name of the config setting
  # @param val [Object] The value of the config setting
  #
  def set(key, val)
    opt = _opt(key)
    Items.validate(val, opt[:name], opt[:validate])
    @data[key] = val
  end


  ###############################################
  # Get the default value
  #
  # @param key [String] The name of the config setting
  def default(key)
    opt = _opt(key)
    opt[:default]
  end


  ###############################################
  # Is the value set?
  #
  # @param key [String] The name of the config setting
  #
  def set?(key); @data.key?(key); end


  ###############################################
  # Get setup
  # @param key [String] the specific key to get
  # @return [Hash, Array] the setup for the key or
  #   an array of \[key, setup\]
  #
  def setup(key=nil)
    return _opt(key) if key

    return @order.map do |key|
      [key, @setup[key]]
    end
  end # def setup


  ###############################################
  # Where to store objects
  #
  def _key(unam)
    @pre + unam
  end # def _key()
  private :_key


  ###############################################
  # Parse JSON encoded config settings
  def _parse(json)

    if json.nil?
      raise(Error::NotFound, 'Config not found')
    end

    begin
     itm = JSON.parse(json)
    rescue
     raise(Error::Value, 'JSON parsing failed')
    end

    errs = {}
    itm.each do |key, val|
      opt = @setup[key]
      raise(Error::Value, 'Unsupported config option %s' % key) if !opt
      err = Validate.check(val, opt[:validate])
      errs[key] = err if err
    end
    unless errs.empty?
      raise(Error::Value, 'Config has bad settings: %s' % errs.inspect)
    end

    @data = itm
  end
  private :_parse


  ###############################################
  # Generate a JSON encoded string
  def _generate()
    JSON.pretty_generate(@data)
  end


  ###############################################
  # Load a user configuration
  #
  # @param unam [String] the user name to load
  # @return [Boolean] if any config data was found for the user
  #
  def load(unam); raise NotImplementedError; end


  ###############################################
  # Save a user configuration
  #
  def save; raise NotImplementedError; end


end # class ICFS::Config

end # module ICFS
