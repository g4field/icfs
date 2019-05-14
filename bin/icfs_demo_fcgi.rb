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

require 'yaml'
require 'faraday'

require_relative '../lib/icfs'
require_relative '../lib/icfs/cache_elastic'
require_relative '../lib/icfs/store_fs'
require_relative '../lib/icfs/users_fs'
require_relative '../lib/icfs/web/client'
require_relative '../lib/icfs/web/auth_ssl'
require_relative '../lib/icfs/demo/timezone'

# load the config file
cfg = YAML.load_file(ARGV[0])
map = {}
cfg['cache']['map'].each do |key, val|
  map[key.to_sym] = val
end

es = Faraday.new(cfg['elastic']['base'])
cache = ICFS::CacheElastic.new(map, es)
store = ICFS::StoreFs.new(cfg['store']['dir'])
users = ICFS::UsersFs.new(cfg['users']['dir'])
api = ICFS::Api.new([], users, cache, store)
web = ICFS::Web::Client.new(cfg['web']['css'], cfg['web']['script'])

user_map = {
  'CN=client 1,OU=Test Client,OU=example,OU=org' => 'user1',
  'CN=client 2,OU=Test Client,OU=example,OU=org' => 'user2',
  'CN=client 3,OU=Test Client,OU=example,OU=org' => 'user3'
}

app = Rack::Builder.new do
  use(ICFS::Web::AuthSsl, user_map, api)
  use(ICFS::Demo::Timezone, cfg['web']['tz'])
  run web
end

puts 'try to run'
Rack::Handler::FastCGI.run(app, {Host: '127.0.0.1', Port: 9000} )
