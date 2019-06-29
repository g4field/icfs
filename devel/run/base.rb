#!/usr/bin/env ruby
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

require 'faraday'
require 'aws-sdk-s3'
require 'redis'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/users_s3'
require_relative '../../lib/icfs/users_redis'
require_relative '../../lib/icfs/config_s3'
require_relative '../../lib/icfs/config_redis'

#################################################
# Get the API
#
def get_base

  # the log
  log = Logger.new(STDERR)
  log.level = Logger::INFO

  # S3
  s3 = Aws::S3::Client.new(
    endpoint: 'http://minio:9000',
    access_key_id: 'minio_key',
    secret_access_key: 'minio_secret',
    force_path_style: true,
    region: 'us-east-1'
  )

  # redis
  redis = Redis.new(host: 'redis')

  # elasic
  es = Faraday.new('http://elastic:9200')

  # default mapping
  map = {
    entry: 'entry',
    case: 'case',
    action: 'action',
    index: 'index',
    log: 'log',
    lock: 'lock',
    current: 'current',
  }.freeze

  # default config
  defaults = {
    'tz' => '-04:00'
  }

  # base objects
  cache = ICFS::CacheElastic.new(map, es)
  store = ICFS::StoreS3.new(s3, 'icfs', 'case/')
  users_base = ICFS::UsersS3.new(s3, 'icfs', 'users/')
  users = ICFS::UsersRedis.new(redis, users_base, {
      prefix: 'users/',
      expires: 60, # one minute cache for testing
      log: log,
    })
  config_base = ICFS::ConfigS3.new(defaults, s3, 'icfs', 'config/')
  config = ICFS::ConfigRedis.new(redis, config_base, {
      prefix: 'config/',
      expires: 60,  # debug, only cache for one minute
    })
  api = ICFS::Api.new([], users, cache, store, config)

  return {
    cache: cache,
    store: store,
    users: users,
    config: config,
    api: api,
    log: log,
  }

end # def base
