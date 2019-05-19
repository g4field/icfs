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

require 'set'

module ICFS

##########################################################################
# User, Role, Group, and Global Perms
#
#
# @abstract
#
# @todo Add cache flush method
#
class Users

  ###############################################
  # Validate a user
  #
  ValUser = {
    method: :hash,
    required: {
      'name' => Items::FieldUsergrp,
      'type' => {
        method: :string,
        allowed: Set[
          'user'.freeze,
          'role'.freeze,
          'group'.freeze,
        ].freeze
      }.freeze
    }.freeze,
    optional: {
      'roles' => {
        method: :array,
        check: Items::FieldUsergrp,
        uniq: true
      }.freeze,
      'groups' => {
        method: :array,
        check: Items::FieldUsergrp,
        uniq: true
      }.freeze,
      'perms' => {
        method: :array,
        check: Items::FieldPermGlobal,
        uniq: true
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # Read a user/role/group
  #
  # @param urg [String] User/Role/Group name
  # @return [Hash] Will include :type and, if a user :roles, :groups, :perms
  #
  def read(urg); raise NotImplementedError; end


  ###############################################
  # Write a user/role/group
  #
  # @param obj [Hash] Will include :name, :type, and if a user
  #    :roles, :groups, :perms
  #
  def write(obj); raise NotImplementedError; end


end # class ICFS::Users

end # module ICFS
