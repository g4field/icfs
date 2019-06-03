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

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/users_fs'

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
es = Faraday.new('http://icfs-elastic:9200')
cache = ICFS::CacheElastic.new(map, es)
store = ICFS::StoreS3.new(s3, 'icfs-cache')
users = ICFS::UsersFs.new('/var/lib/icfs/users')

# create users dir
FileUtils.mkdir_p('/var/lib/icfs/users')
puts "Created users directory"

# put a testuser
tusr = {
  'name' => 'testuser',
  'type' => 'user',
}
users.write(tusr)
puts "Added testuser"

# create the indexes
cache.create(ICFS::CacheElastic::Maps)
puts "Indexes created"

# create a bucket
s3.create_bucket(bucket: 'icfs-cache')
puts "Bucket created"

api = ICFS::Api.new([], users, cache, store)
api.user = 'testuser'

# add a template
tmpl = {
  'template' => true,
  'status' => true,
  'title' => 'Test template',
  'access' => [
    {
      'perm' => '[manage]',
      'grant' => [
        'testuser'
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
