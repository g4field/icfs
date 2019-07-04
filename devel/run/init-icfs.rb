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

require 'json'
require 'faraday'
require 'aws-sdk-s3'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'

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
s3 = Aws::S3::Client.new(
  endpoint: 'http://minio:9000',
  access_key_id: 'minio_key',
  secret_access_key: 'minio_secret',
  force_path_style: true,
  region: 'us-east-1'
)
es = Faraday.new('http://elastic:9200')
cache = ICFS::CacheElastic.new(map, es)

# create the indexes
cache.create(ICFS::CacheElastic::Maps)
puts "Indexes created"

# create a bucket
s3.create_bucket(bucket: 'icfs')
puts "S3 bucket created"
