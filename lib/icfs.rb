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

require 'digest/sha2'

require_relative 'icfs/validate'

##########################################################################
# Investigative Case File System
#
module ICFS


  # no tags
  TagNone = '[none]'

  # edits an action
  TagAction = '[action]'

  # edits an index
  TagIndex = '[index]'

  # edits the case
  TagCase = '[case]'


  # permission to read case
  PermRead = '[read]'

  # permission to write case
  PermWrite = '[write]'

  # permission to manage case
  PermManage = '[manage]'

  # permission to manage actions
  PermAction = '[action]'

  # global permission to search
  PermSearch = '{[search]}'


  # user group
  UserCase = '[case]'


  ###############################################
  # Hash a string
  def self.hash(str)
    Digest::SHA256.hexdigest(str)
  end


  ###############################################
  # Hash a tempfile
  #
  def self.hash_temp(tf)
    Digest::SHA256.file(tf.path).hexdigest
  end




##########################################################################
# Error
#
module Error


##########################################################################
# Invalid values
class Value < ArgumentError; end

##########################################################################
# Item not found
class NotFound < RuntimeError; end

##########################################################################
# Do not have required permissions
class Perms < RuntimeError; end

##########################################################################
# Conflict with pre-existing values
class Conflict < RuntimeError; end

##########################################################################
# Interface errors
class Interface < RuntimeError; end

end # module ICFS::Error

end # module ICFS

require_relative 'icfs/cache'
require_relative 'icfs/store'
require_relative 'icfs/items'
require_relative 'icfs/api'
require_relative 'icfs/users'
