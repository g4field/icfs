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

# frozen_string_literal: true

require_relative 'api'
require_relative '../../lib/icfs/email/from'
require_relative '../../lib/icfs/email/basic'
require_relative '../../lib/icfs/email/imap'

# api
api = get_api
log = Logger.new(STDERR)
log.level = Logger::DEBUG

# load the email map
map_email = JSON.parse(File.read(ARGV[0]))

# load the IMAP config
cfg_raw = JSON.parse(File.read(ARGV[1]))
cfg = {}
cfg_raw.each{|key, val| cfg[key.to_sym] = val}

# email gateway
email_basic = ICFS::Email::Basic.new
email_from = ICFS::Email::From.new(map_email)
email = ICFS::Email::Core.new(api, [email_from, email_basic])
imap = ICFS::Email::Imap.new(email, log, cfg)

# and fetch
imap.fetch
