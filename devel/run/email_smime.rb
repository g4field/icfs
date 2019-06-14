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

# <app> <srv_cert.pem> <srv_key.pem> <ca.pem> < <email.eml>

require 'faraday'
require 'aws-sdk-s3'
require 'redis'

require_relative '../../lib/icfs'
require_relative '../../lib/icfs/cache_elastic'
require_relative '../../lib/icfs/store_s3'
require_relative '../../lib/icfs/users_s3'
require_relative '../../lib/icfs/users_redis'
require_relative '../../lib/icfs/email/rx_smime'
require_relative '../../lib/icfs/email/rx_core'

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

# load the email map
cert = ::OpenSSL::X509::Certificate.new(File.read(ARGV[0]))
key = ::OpenSSL::PKey.read(File.read(ARGV[1]))
ca = ::OpenSSL::X509::Store.new
ca.add_file(ARGV[2])

map_cn = {
  'CN=client 1,OU=Test Client,OU=example,OU=org' => 'user1',
  'CN=client 2,OU=Test Client,OU=example,OU=org' => 'user2',
  'CN=client 3,OU=Test Client,OU=example,OU=org' => 'user3',
}

# email gateway
email_core = ICFS::Email::RxCore.new
email_smime = ICFS::Email::RxSmime.new(key, cert, ca, map_cn)
email = ICFS::Email::Rx.new(api, [email_smime, email_core])

txt = STDIN.read
res = email.receive(txt)

p res
