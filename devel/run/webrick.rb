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

require 'faraday'
require 'aws-sdk-s3'
require 'redis'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/users_s3'
require_relative '../../lib/icfs/users_redis'
require_relative '../../lib/icfs/web/client'
require_relative '../../lib/icfs/web/config_s3'
require_relative '../../lib/icfs/web/config_redis'
require_relative '../../lib/icfs/demo/auth'
require_relative '../../lib/icfs/demo/static'

# Minio config
Aws.config.update(
  endpoint: 'http://minio:9000',
  access_key_id: 'minio_key',
  secret_access_key: 'minio_secret',
  force_path_style: true,
  region: 'us-east-1'
)

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

# the log
log = Logger.new(STDERR)
log.level = Logger::INFO

# base items
s3 = Aws::S3::Client.new
redis = Redis.new(host: 'redis')
es = Faraday.new('http://elastic:9200')
cache = ICFS::CacheElastic.new(map, es)
store = ICFS::StoreS3.new(s3, 'icfs'.freeze, 'case/'.freeze)
users_base = ICFS::UsersS3.new(s3, 'icfs'.freeze, 'users/'.freeze)
users = ICFS::UsersRedis.new(redis, users_base, {
    prefix: 'users/'.freeze,
    expires: 60, # one minute cache for testing
    log: log,
  })
api = ICFS::Api.new([], users, cache, store)
config_base = ICFS::Web::ConfigS3.new(defaults, s3, 'icfs', 'config/')
config = ICFS::Web::ConfigRedis.new(redis, config_base, {
    prefix: 'config/',
    expires: 60,  # debug, only cache for one minute
  })
web = ICFS::Web::Client.new('/static/icfs.css', '/static/icfs.js')

# static files
static = {
  '/static/icfs.css' => {
    'path' => '/icfs/data/icfs.css',
    'mime' => 'text/css; charset=utf-8'
  },
  '/static/icfs.js' => {
    'path' => '/icfs/data/icfs.js',
    'mime' => 'application/javascript; charset=utf-8'
  }
}

app = Rack::Builder.new do
  use(ICFS::Demo::Auth, api, config)
  use(ICFS::Demo::Static, static)
  run web
end

opts = {}
opts[:Host] = "0.0.0.0"
opts[:Port] = 8080

Rack::Handler::WEBrick.run(app, opts)
