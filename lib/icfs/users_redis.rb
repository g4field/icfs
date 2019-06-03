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

require 'redis'

module ICFS

##########################################################################
# Implement Users with a Redis cache
#
class UsersRedis < Users

  ###############################################
  # New instance
  #
  # @param redis [Redis] The redis client
  # @param base [Users] The base Users store
  # @param opts [Hash] Options
  # @option opts [String] :prefix Prefix for Redis key
  # @option opts [Integer] :expires Expiration time in seconds
  #
  def initialize(redis, base, opts={})
    @redis = redis
    @base = base
    @pre = opts[:prefix] || ''.freeze
    @exp = opts[:expires] || 1*60*60 # 1 hour default
  end


  ###############################################
  # Where to store in Redis
  #
  def _key(urg)
    @pre + urg
  end
  private :_key


  ###############################################
  # (see Users#read)
  #
  def read(urg)
    Validate.check(urg, Items::FieldUsergrp) # FIXME
    key = _key(urg)

    # try cache
    json = @redis.get(key)
    return JSON.parse(json) if json

    # get base object from base store
    bse = @base.read(urg)
    return nil if !bse

    # assemble
    seen = Set.new.add(urg)
    ary = []
    roles = Set.new
    grps = Set.new
    perms = Set.new
    if bse['roles']
      ary.concat bse['roles']
      roles.merge bse['roles']
    end
    if bse['groups']
      ary.concat bse['groups']
      grps.merge bse['groups']
    end
    if bse['perms']
      perms.merge bse['perms']
    end

    # call ourself recursively for any un-expanded memberships
    while itm = ary.shift
      next if seen.include?(itm)
      seen.add(itm)
      ikey = _key(itm)

      # all included u/r/g have been seen & expanded
      mem = self.read(itm)
      next if !mem
      if mem['roles']
        roles.merge mem['roles']
        seen.merge mem['roles']
      end
      if mem['groups']
        grps.merge mem['groups']
        seen.merge mem['groups']
      end
      if mem['perms']
        perms.merge mem['perms']
      end
    end

    # final result
    bse['roles'] = roles.to_a unless roles.empty?
    bse['groups'] = grps.to_a unless grps.empty?
    bse['perms'] = perms.to_a unless perms.empty?
    json = JSON.pretty_generate(bse)

    # save to cache
    @redis.set(key, json)
    @redis.expire(key, @exp)
    return bse
  end # def read()


  ###############################################
  # (see Users#write)
  #
  def write(obj)
    json = Items.generate(obj, 'User/Role/Group'.freeze, Users::ValUser)
    key = _key(obj['name'])
    @redis.del(key)
    @base.write(obj)
  end # def write()

end # class ICFS::UsersRedis

end # module ICFS
