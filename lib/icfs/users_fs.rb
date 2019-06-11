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
require 'json'

require_relative 'users'

module ICFS

##########################################################################
# Implements {ICFS::Users Users} from a file system
#
class UsersFs < Users


  ###############################################
  # New instance
  #
  # @param path [String] Base directory
  #
  def initialize(path)
    @path = path.dup
  end


  ###############################################
  # Path to store the file
  #
  def _path(urg)
    File.join(@path, urg + '.json'.freeze)
  end
  private :_path


  ###############################################
  # (see Users#flush)
  #
  def flush(urg); false; end


  ###############################################
  # (see Users#read)
  #
  def read(urg)
    Items.validate(urg, 'User/Role/Group name'.freeze, Items::FieldUsergrp)
    json = File.read(_path(urg))
    obj = Items.parse(json, 'User/Role/Group'.freeze, Users::ValUser)
    if obj['name'] != urg
      raise(Error::Values, 'UsersFs user %s name mismatch'.freeze % fn)
    end
    return obj
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
    FileUtils.mv(tmp.path, _path(obj['name']))
    tmp.unlink
  end # def write()


end # class ICFS::UsersFs

end # module ICFS
