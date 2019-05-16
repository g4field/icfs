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
require_relative '../lib/icfs/demo/auth'
require_relative '../lib/icfs/demo/static'
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

app = Rack::Builder.new do
  use(ICFS::Demo::Auth, api)
  use(ICFS::Demo::Static, cfg['web']['static'])
  use(ICFS::Demo::Timezone, cfg['web']['tz'])
  run web
end

opts = {}
opts[:Host] = cfg['web']['host'] if cfg['web']['host']
opts[:Port] = cfg['web']['port'] if cfg['web']['port']

Rack::Handler::WEBrick.run(app, opts)
