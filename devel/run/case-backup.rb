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

# usage: <case-backup> <fs_store_dir> <caseid>

# frozen_string_literal: true

require_relative 'base'
require_relative '../../lib/icfs/store_fs'
require_relative '../../lib/icfs/utils/backup'

base = get_base()
backup = ICFS::Utils::Backup.new(base[:cache], base[:store], base[:log])
dst = ICFS::StoreFs.new(ARGV[0])
backup.copy(ARGV[1], dst)
