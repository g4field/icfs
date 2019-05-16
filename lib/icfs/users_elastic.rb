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
require_relative 'elastic'

module ICFS

##########################################################################
# Implements {ICFS::Users Users} using Elasticsearch to cache
# details from another {ICFS::Users Users} instance.
#
class UsersElastic < Users

  include Elastic

  private

  ###############################################
  # The ES mappings for the indexes
  #
  Maps = {
    :users => '{
  "mappings": { "_doc": { "properties": {
    "name": { "type": "text" },
    "type": { "type": "keyword" },
    "roles": { "type": "keyword" },
    "groups": { "type": "keyword" },
    "perms": { "type": "keyword" },
    "first": { "enabled": false },
    "last": { "type": "date", "format": "epoch_second" },
    "active": { "type": "boolean" }
  }}}
}'.freeze,
  }.freeze

  public

  ###############################################
  # New instance
  #
  # @param map [Hash] Symbol to String of the indexes.
  #    Must provide :user
  # @param es [Faraday] Faraday instance to the Elasticsearch cluster
  # @param src [Users] Source of authoritative information
  # @param exp [Integer] Maximum time to cache a response
  #
  def initialize(map, es, src, exp=3600)
    @map = map
    @es = es
    @src = src
    @exp = exp
  end


  ###############################################
  # Validate a user
  #
  ValUserCache = {
    method: :hash,
    required: {
      'name' => Items::FieldUsergrp,
      'type' => {
        method: :string,
        allowed: Set[
          'user'.freeze,
          'role'.freeze,
          'group'.freeze,
        ].freeze
      }.freeze,
      'first' => Validate::IsIntPos,
      'last' => Validate::IsIntPos,
      'active' => Validate::IsBoolean,
    }.freeze,
    optional: {
      'roles' => {
        method: :array,
        check: Items::FieldUsergrp,
        uniq: true
      }.freeze,
      'groups' => {
        method: :array,
        check: Items::FieldUsergrp,
        uniq: true
      }.freeze,
      'perms' => {
        method: :array,
        check: Items::FieldPermGlobal,
        uniq: true
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # (see Users#read)
  #
  def read(urg)
    json = _read(:users, urg)
    now = Time.now.to_i

    # not in the cache
    if !json

      # read from source
      obj = @src.read(urg)
      return nil if !obj

      # first time
      obj['first'] = now
      obj['last'] = now
      obj['active'] = true

      # store in cache
      json = Items.generate(obj, 'User/Role/Group'.freeze, ValUserCache)
      _write(:users, urg, json)

    # use cached version
    else
      obj = Items.parse(json, 'User/Role/Group'.freeze, ValUserCache)
    end

    # expired
    if (obj['last'] + @exp) < now

      # read from source
      obj2 = @src.read(urg)

      # update
      if obj2
        obj['active'] = true
        obj['roles'] = obj2['roles']
        obj['groups'] = obj2['groups']
        obj['perms'] = obj2['perms']
      else
        obj['active'] = false
      end
      obj['last'] = now

      # and store in cache
      json = Items.generate(obj, 'User/Role/Group'.freeze, ValUserCache)
      _write(:users, urg, json)
    end

    # not active
    return nil unless obj['active']

    # clean out cached info
    obj.delete('first'.freeze)
    obj.delete('last'.freeze)
    obj.delete('active'.freeze)

    return obj
  end # def read()

end # class ICFS::Users

end # module ICFS
