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

# <app> <srv_cert.pem> <srv_key.pem> <ca.pem> < <email.eml>

# frozen_string_literal: true

require_relative 'api'
require_relative '../../lib/icfs/email/smime'
require_relative '../../lib/icfs/email/basic'

# api
api = get_api
log = Logger.new(STDERR)
log.level = Logger::DEBUG

# load the email map
cert = ::OpenSSL::X509::Certificate.new(File.read(ARGV[0]))
key = ::OpenSSL::PKey.read(File.read(ARGV[1]))
ca = ::OpenSSL::X509::Store.new
ca.add_file(ARGV[2])

map_cn = {
  'CN=client 1,OU=Test Client,OU=example,OU=org' => 'user1',
  'CN=client 2,OU=Test Client,OU=example,OU=org' => 'user2',
  'CN=client 3,OU=Test Client,OU=example,OU=org' => 'user3',
}

# email gateway
email_basic = ICFS::Email::Basic.new
email_smime = ICFS::Email::Smime.new(key, cert, ca, map_cn)
email = ICFS::Email::Core.new(api, log, [email_smime, email_basic])

txt = STDIN.read
res = email.receive(txt)

p res
