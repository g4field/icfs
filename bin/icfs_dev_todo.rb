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


require 'yard'

YARD::Registry.load!.all.each do |o|
  todo = o.tags(:todo)
  next if todo.empty?
  todo.each{|tg| puts "%s\n  %s\n\n" % [o.path, tg.text] }
end
