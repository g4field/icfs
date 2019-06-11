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

require_relative 'config'

module ICFS
module Web

##########################################################################
# Implement Config with a Redis cache
#
class ConfigRedis < Config


  ###############################################
  # New instance
  #
  # @param redis [Redis] The redis client
  # @param base [Config] The base Config store
  # @param opts [Hash] Options
  # @option opts [String] :prefix Prefix for Redis key
  # @option opts [Integer] :expires Expiration time in seconds
  #
  def initialize(redis, base, opts={})
    super(base.defaults)
    @redis = redis
    @base = base
    @pre = opts[:prefix] || ''.freeze
    @exp = opts[:expires] || 1*60*60 # 1 hour default
  end


  ###############################################
  # (see Config#load)
  #
  def load(unam)
    Items.validate(unam, 'User/Role/Group name'.freeze, Items::FieldUsergrp)
    @unam = unam.dup
    key = _key(unam)

    # try cache
    json = @redis.get(key)
    if json
      @data = Items.parse(json, 'Config values'.freeze, Config::ValConfig)
      return true
    end

    # get base object
    succ = @base.load(unam)
    @data = @base.data
    return succ
  end # def load()


  ###############################################
  # (see Config#save)
  #
  def save()
    raise(RuntimeError, 'Save requires a user name'.freeze) if !@unam
    json = Items.generate(@data, 'Config values'.freeze, Config::ValConfig)
    @redis.del(_key(@unam))
    @base.data = @data
    @base.save
  end # def save()


end # class ICFS::Web::Config

end # module ICFS::Web
end # module ICFS