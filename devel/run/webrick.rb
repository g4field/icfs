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

require_relative 'base'
require_relative '../../lib/icfs/web/client'
require_relative '../../lib/icfs/demo/auth'
require_relative '../../lib/icfs/demo/static'

base = get_base()
api = base[:api]

web = ICFS::Web::Client.new('/static/icfs.js')

# static files
static = {
  '/static/icfs.css' => {
    'path' => '/icfs/data/icfs.css',
    'mime' => 'text/css; charset=utf-8'
  },
  '/static/icfs-dark.css' => {
    'path' => '/icfs/data/icfs-dark.css',
    'mime' => 'text/css; charset=utf-8'
  },
  '/static/icfs.js' => {
    'path' => '/icfs/data/icfs.js',
    'mime' => 'application/javascript; charset=utf-8'
  }
}

app = Rack::Builder.new do
  use(ICFS::Demo::Auth, api)
  use(ICFS::Demo::Static, static)
  run web
end

opts = {}
opts[:Host] = "0.0.0.0"
opts[:Port] = 8080

Rack::Handler::WEBrick.run(app, opts)
