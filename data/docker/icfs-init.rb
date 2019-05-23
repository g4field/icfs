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
require 'rack'
require 'yaml'
require 'fileutils'

require 'icfs'
require 'icfs/cache_elastic'
require 'icfs/store_fs'
require 'icfs/users_fs'


# load the config file
cfg = YAML.load_file('/etc/icfs.yml')
map = {}
cfg['cache']['map'].each{|key, val| map[key.to_sym] = val }

# sleep to allow elasticsearch to come up
if cfg['sleep']
  puts 'sleeping: %f' % cfg['sleep']
  sleep(cfg['sleep'])
end

es = Faraday.new(cfg['elastic']['base'])
cache = ICFS::CacheElastic.new(map, es)
store = ICFS::StoreFs.new(cfg['store']['dir'])
users = ICFS::UsersFs.new(cfg['users']['dir'])
api = ICFS::Api.new([], users, cache, store)

# create store and users
FileUtils.mkdir(cfg['store']['dir'])
puts "Created store directory: %s" % cfg['store']['dir']
FileUtils.mkdir(cfg['users']['dir'])
puts "Created users directory: %s" % cfg['users']['dir']

# add the users
cfg['init']['urg'].each do |usr|
  users.write(usr)
  puts "Added user/role/group: %s" % usr['name']
end

# create the indexes
cache.create(ICFS::CacheElastic::Maps)
puts "Indexes created"

# set initial user
api.user = cfg['init']['user']

# add the templates
cfg['init']['templates'].each do |tmpl|
  tp = {
    'template' => true,
    'status' => true,
    'title' => tmpl['template'],
    'access' => tmpl['access'],
  }
  ent = {
    'caseid' => tmpl['caseid'],
    'title' => tmpl['entry'],
    'content' => tmpl['content']
  }
  api.case_create(ent, tp)
  puts "Created template: %s" % tmpl['caseid']
end
