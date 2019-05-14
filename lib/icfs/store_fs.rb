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

require 'fileutils'
require 'tempfile'

module ICFS

##########################################################################
# Permanent store for items using the filesystem
#
# @deprecated Using a filesystem for a production system is a horrible idea.
#   This is provided as an example and should be used for development use
#   only.
#
class StoreFs < Store

  ###############################################
  # New instance
  #
  # @param base [String] the base directory
  #
  def initialize(base)
    @base = base.freeze
  end


  ###############################################
  # (see Store#file_read)
  #
  def file_read(cid, enum, lnum, fnum)
    File.open(_file(cid, enum, lnum, fnum), 'rb')
  rescue Errno::ENOENT
    return nil
  end


  ###############################################
  # (see Store#file_write)
  #
  def file_write(cid, enum, lnum, fnum, tmpf)
    fn = _file(cid, enum, lnum, fnum)
    FileUtils.ln(tmpf.path, fn, force: true)
    tmpf.close!
  rescue Errno::ENOENT
    FileUtils.mkdir_p(File.dirname(fn))
    FileUtils.ln(tmpf.path, fn, force: true)
    tmpf.close!
  end


  ###############################################
  # (see Store#tempfile)
  #
  def tempfile
    Tempfile.new('tmp'.freeze, @base, :encoding => 'ascii-8bit'.freeze)
  end


  private


  ###############################################
  # Read an item
  #
  def _read(fnam)
    return File.read(fnam, encoding: 'utf-8'.freeze)
  rescue Errno::ENOENT
    return nil
  end


  ###############################################
  # Write an item
  #
  def _write(fnam, item)
    File.open(fnam, 'w'.freeze, encoding: 'utf-8'.freeze) do |fi|
      fi.write(item)
    end
  rescue Errno::ENOENT
    FileUtils.mkdir_p(File.dirname(fnam))
    File.open(fnam, 'w'.freeze, encoding: 'utf-8'.freeze) do |fi|
      fi.write(item)
    end
  end


end # class StoreFs

end # module ICFS
