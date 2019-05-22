#!/usr/bin/env ruby

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

# clear out the store
if File.exists?(cfg['store']['dir'])
  FileUtils.rm_rf(cfg['store']['dir'])
  puts "Deleted store directory"
end
FileUtils.mkdir(cfg['store']['dir'])
puts "Created store directory: %s" % cfg['store']['dir']

# clear out the users
if File.exists?(cfg['users']['dir'])
  FileUtils.rm_rf(cfg['users']['dir'])
  puts "Deleted users directory"
end
FileUtils.mkdir(cfg['users']['dir'])
puts "Created users directory: %s" % cfg['users']['dir']


# test
File.open('/var/lib/icfs/test.txt', 'w'){|fi| fi.write "test\n"}

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


