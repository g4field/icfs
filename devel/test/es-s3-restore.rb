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


# usage <caseid> <store_fs>

require 'json'
require 'faraday'
require 'aws-sdk-s3'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/store_fs'
require_relative '../../lib/icfs/utils/backup'

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
log = Logger.new(STDOUT, level: Logger::DEBUG)

src = ICFS::StoreFs.new(ARGV[1])
backup = ICFS::Utils::Backup.new(cache, store, log)
backup.restore(ARGV[0], src)

