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

#
module ICFS
module Web

##########################################################################
# Configuration storage interface
#
# @abstract
#
class Config

  ###############################################
  # Valid config options
  ValConfig = {
    method: :hash,
    optional: {
      'tz' => {
        method: :string,
        valid: /[+\-](0[0-9]|1[0-2]):[0-5][0-9]/.freeze,
        whitelist: true,
      }
    }
  }

  ###############################################
  # New instance
  #
  # @param defaults [Hash] The default options
  #
  def initialize(defaults={})
    @data = {}
    @unam = nil
    @defaults = defaults
  end # def initialize()


  ###############################################
  # The configuration values hash
  #
  attr_accessor :data


  ###############################################
  # The configuration defaults
  #
  attr_reader :defaults


  ###############################################
  # Get a value
  #
  # @param key [String] The name of the config setting
  #
  def get(key)
    @data.key?(key) ? @data[key] : @defaults[key]
  end


  ###############################################
  # Set a value
  #
  # @param key [String] The name of the config setting
  # @param val [Object] The value of the config setting
  #
  def set(key, val)
    @data[key] = val
  end


  ###############################################
  # Where to store objects
  #
  def _key(unam)
    @pre + unam
  end # def _key()
  private :_key


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


end # class ICFS::Web::Config

end # module ICFS::Web
end # module ICFS
