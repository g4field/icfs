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

# usage: <case-restore> <fs_store_dir> <caseid>

# frozen_string_literal: true

require_relative 'base'
require_relative '../../lib/icfs/store_fs'
require_relative '../../lib/utils/backup'

base = get_base()
backup = ICFS::Utils::Backup.new(base[:cache], base[:store], base[:log])
src = ICFS::StoreFs.new(ARGV[0])
backup.restore(ARGV[1], src)
