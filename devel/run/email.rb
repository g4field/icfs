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
require_relative '../../lib/icfs/email/rx_from'
require_relative '../../lib/icfs/email/rx_core'

# api
api = get_api

# load the email map
map_email = JSON.parse(File.read(ARGV[0]))

# email gateway
email_core = ICFS::Email::RxCore.new
email_from = ICFS::Email::RxFrom.new(map_email)
email = ICFS::Email::Rx.new(api, [email_from, email_core])

txt = STDIN.read
res = email.receive(txt)

p res
