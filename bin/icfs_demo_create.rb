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
require 'json'
require 'faraday'
require 'fileutils'

require_relative '../lib/icfs'
require_relative '../lib/icfs/cache_elastic'
require_relative '../lib/icfs/store_fs'
require_relative '../lib/icfs/users_fs'

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

# clear out the store
if File.exists?(cfg['store']['dir'])
  FileUtils.rm_rf(cfg['store']['dir'])
  puts "Deleted store directory"
end
FileUtils.mkdir_p(cfg['store']['dir'])
puts "Created store directory: %s" % cfg['store']['dir']

# clear out the users
if File.exists?(cfg['users']['dir'])
  FileUtils.rm_rf(cfg['users']['dir'])
  puts "Deleted users directory"
end
FileUtils.mkdir_p(cfg['users']['dir'])
puts "Created users directory: %s" % cfg['users']['dir']

# delete the indexes
map.each do |sym, name|
  resp = es.run_request(:delete, name, '', {})
  if resp.success?
    puts 'Deleted index: %s' % name
  else
    puts 'Failed to delete index: %s' % name
  end
end

# add the users
cfg['init']['urg'].each do |usr|
  users.write(usr)
  puts "Added user/role/group: %s" % usr['name']
end

# create the indexes
cache.create(ICFS::CacheElastic::Maps)
puts "Indexes created"

api = ICFS::Api.new([], users, cache, store)
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
