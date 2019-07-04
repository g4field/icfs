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

# usage: ./copy-s3.rb <source_dir> <prefix>

# frozen_string_literal: true

require 'aws-sdk-s3'
require 'find'

require_relative '../../lib/icfs'

# Minio config
Aws.config.update(
  endpoint: 'http://minio:9000',
  access_key_id: 'minio_key',
  secret_access_key: 'minio_secret',
  force_path_style: true,
  region: 'us-east-1'
)

s3 = Aws::S3::Client.new

dir = ARGV[0]
prefix = ARGV[1]
size = (dir[-1] == '/') ? dir.size : dir.size + 1

# copy in all the files in the dir
Find.find(dir) do |fn|
  next unless File.file?(fn)

  rel = fn[size..-1]
  key = prefix + rel

  cont = File.binread(fn)
  s3.put_object( bucket: 'icfs', key: key, body: cont )
  puts key
end
