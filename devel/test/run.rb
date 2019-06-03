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

require 'json'
require 'faraday'
require 'fileutils'
require 'aws-sdk-s3'
require 'redis'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/users_fs'
require_relative '../../lib/icfs/users_redis'
require_relative '../../lib/icfs/web/client'
require_relative '../../lib/icfs/demo/auth'
require_relative '../../lib/icfs/demo/static'

# Minio config
Aws.config.update(
  endpoint: 'http://icfs-minio:9000',
  access_key_id: 'minio_key',
  secret_access_key: 'minio_secret',
  force_path_style: true,
  region: 'use-east-1'
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

# base items
s3 = Aws::S3::Client.new
redis = Redis.new(host: 'icfs-redis')
es = Faraday.new('http://icfs-elastic:9200')
cache = ICFS::CacheElastic.new(map, es)
store = ICFS::StoreS3.new(s3, 'icfs-data', 'store/')
users_base = ICFS::UsersFs.new(ARGV[0])
users = ICFS::UsersRedis.new(redis, users_base, {
    prefix: 'users/'.freeze,
    expires: 60, # one minute cache for testing
  })
api = ICFS::Api.new([], users, cache, store)
web = ICFS::Web::Client.new('/static/icfs.css', '/static/icfs.js')

# static files
static = {
  '/static/icfs.css' => {
    'path' => 'data/icfs.css',
    'mime' => 'text/css; charset=utf-8'
  },
  '/static/icfs.js' => {
    'path' => 'data/icfs.js',
    'mime' => 'application/javascript; charset=utf-8'
  }
}

app = Rack::Builder.new do
  use(ICFS::Demo::Auth, api)
  use(ICFS::Demo::Static, static)
  run web
end

opts = {}
opts[:Host] = "0.0.0.0"
opts[:Port] = 8080

Rack::Handler::WEBrick.run(app, opts)
