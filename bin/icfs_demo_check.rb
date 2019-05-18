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
require 'logger'

require_relative '../lib/icfs'
require_relative '../lib/icfs/utils/check'
require_relative '../lib/icfs/store_fs'

# load the config file
cfg = YAML.load_file(ARGV[0])

# objects
store = ICFS::StoreFs.new(cfg['store']['dir'])
log = Logger.new(STDOUT, level: Logger::INFO)
check = ICFS::Utils::Check.new(store, log)

# check
check.check(ARGV[1], ARGV[2].to_i, nil, {hash_all: true})
