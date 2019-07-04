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

# usage: ./init-template.sh <template.json> <user>

# frozen_string_literal: true

require_relative 'base'

json = File.read(ARGV[0])
tmpl = ICFS::Items.parse(json, 'Template', ICFS::Items::ItemCase)
tmpl.delete('icfs')
tmpl.delete('log')

ent = {
  'caseid' => tmpl['caseid'],
  'title' => 'Create case',
  'content' => 'Added case using manual script',
}

base = get_base()
api = base[:api]

api.case_create(ent, tmpl, nil, ARGV[1])
