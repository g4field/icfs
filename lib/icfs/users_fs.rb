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

require 'tempfile'
require 'fileutils'
require 'set'

module ICFS

##########################################################################
# Implements {ICFS::Users Users} from a file system
#
class UsersFs < Users

  private

  ###############################################
  # read a raw file
  def _read(fn)
    json = File.read(File.join(@path, fn + '.json'.freeze))
    obj = Items.parse(json, 'User/Role/Group'.freeze, Users::ValUser)
    if obj['name'] != fn
      raise(Error::Values, 'UsersFs user %s name mismatch'.freeze % fn)
    end
    return obj
  end # _read


  public


  ###############################################
  # New instance
  #
  # @param path [String] Base directory
  #
  def initialize(path)
    @path = path.dup
  end


  ###############################################
  # (see Users#read)
  #
  def read(urg)
    Items.validate(urg, 'User/Role/Group'.freeze, Items::FieldUsergrp)

    # get the base user
    usr = _read(urg)
    return usr if usr['type'] != 'user'.freeze

    # assemble
    type = usr['type']
    done_s = Set.new.add(urg)
    ary = []
    roles_s = Set.new
    if usr['roles']
      ary.concat usr['roles']
      roles_s.merge usr['roles']
    end
    grps_s = Set.new
    if usr['groups']
      ary.concat usr['groups']
      grps_s.merge usr['groups']
    end
    perms_s = Set.new
    if usr['perms']
      perms_s.merge usr['perms']
    end

    # roles & groups
    while itm = ary.shift
      next if done_s.include?(itm)
      done_s.add(itm)

      usr = _read(itm)
      if usr['roles']
        ary.concat usr['roles']
        roles_s.merge usr['roles']
      end
      if usr['groups']
        ary.concat usr['groups']
        grps_s.merge usr['groups']
      end
      if usr['perms']
        perms_s.merge usr['perms']
      end
    end

    # assemble final
    return {
      'name' => urg.dup,
      'type' => type,
      'roles' => roles_s.to_a,
      'groups' => grps_s.to_a,
      'perms' => perms_s.to_a,
    }

  rescue Errno::ENOENT
    return nil
  end # def read()


  ###############################################
  # (see Users#write)
  #
  def write(obj)
    Items.validate(obj, 'User/Role/Group'.freeze, Users::ValUser)
    json = JSON.pretty_generate(obj)

    # write to temp file
    tmp = Tempfile.new('_tmp'.freeze, @path, :encoding => 'ascii-8bit'.freeze)
    tmp.write(json)
    tmp.close

    # move
    FileUtils.mv(tmp.path, File.join(@path, obj['name'] + '.json'.freeze))
    tmp.unlink
  end # def write()


end # class ICFS::UsersFs

end # module ICFS
