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

# Elasticsearch cache
# S3 item store
# S3 & Redis Users

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
store = ICFS::StoreS3.new(s3, 'icfs', 'case/')
users_base = ICFS::UsersFs.new(ARGV[0])
users = ICFS::UsersRedis.new(redis, users_base, {
    prefix: 'users/'.freeze,
    expires: 60, # one minute cache for testing
  })

# create the indexes
cache.create(ICFS::CacheElastic::Maps)
puts "Indexes created"

# create a bucket
s3.create_bucket(bucket: 'icfs')
puts "S3 bucket created"

api = ICFS::Api.new([], users, cache, store)
api.user = 'user1'

# add a template
tmpl = {
  'template' => true,
  'status' => true,
  'title' => 'Test template',
  'access' => [
    {
      'perm' => '[manage]',
      'grant' => [
        'role2'
      ]
    }
  ]
}
ent = {
  'caseid' => 'test_tmpl',
  'title' => 'Create template',
  'content' => 'To test'
}
api.case_create(ent, tmpl)
puts "Create template"
