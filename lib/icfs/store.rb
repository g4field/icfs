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

#
module ICFS

##########################################################################
# Permanent store for items
#
# Provides storage for:
# * Case
# * Log
# * Entry
# * Attached files
# * Action
# * Indexes
#
# @abstract
#
class Store

  ###############################################
  # Read a case
  #
  # @param cid [String] caseid
  # @param lnum [Integer] Log number
  # @return [String] The JSON encoded item
  #
  def case_read(cid, lnum); _read(_case(cid, lnum)); end


  ###############################################
  # Write a case
  #
  # @param cid [String] caseid
  # @param lnum [Integer] Log number
  # @param item [String] the JSON encoded item
  #
  def case_write(cid, lnum, item); _write(_case(cid, lnum), item); end


  ###############################################
  # Read a log
  #
  # @param cid [String] caseid
  # @param lnum [Integer] Log number
  # @return [String] The JSON encoded item
  #
  def log_read(cid, lnum); _read(_log(cid, lnum)); end


  ###############################################
  # Write a log
  #
  # @param cid [String] caseid
  # @param lnum [Integer] Log number
  # @param item [String] the JSON encoded item
  #
  def log_write(cid, lnum, item); _write(_log(cid, lnum), item); end


  ###############################################
  # Read an entry
  #
  # @param cid [String] caseid
  # @param enum [Integer] Entry number
  # @param lnum [Integer] Log number
  # @return [String] The JSON encoded item
  #
  def entry_read(cid, enum, lnum); _read(_entry(cid, enum, lnum)); end


  ###############################################
  # Write an entry
  #
  # @param cid [String] caseid
  # @param enum [Integer] Entry number
  # @param lnum [Integer] Log number
  # @param item [String] the JSON encoded item
  #
  def entry_write(cid, enum, lnum, item)
    _write(_entry(cid, enum, lnum), item)
  end


  ###############################################
  # Read a file
  #
  # @param cid [String] caseid
  # @param enum [Integer] Entry number
  # @param lnum [Integer] Log number
  # @param fnum [Integer] File number
  # @return [File,Tempfile] Read only copy of the file
  #
  def file_read(cid, enum, lnum, fnum); raise NotImplementedError; end


  ###############################################
  # Write a file
  #
  # @param cid [String] caseid
  # @param enum [Integer] Entry number
  # @param lnum [Integer] Log number
  # @param fnum [Integer] File number
  # @param tmpf [Tempfile] A Tempfile obtained from #tempfile
  #
  def file_write(cid, enum, lnum, fnum, tmpf); raise NotImplementedError; end


  ###############################################
  # Read an action
  #
  # @param cid [String] caseid
  # @param anum [Integer] Action number
  # @param lnum [Integer] Log number
  # @return [String] The JSON encoded item
  #
  def action_read(cid, anum, lnum)
    _read(_action(cid, anum, lnum))
  end


  ###############################################
  # Write an action
  #
  # @param cid [String] caseid
  # @param anum [Integer] Action number
  # @param lnum [Integer] Log number
  # @param item [String] the JSON encoded item
  #
  def action_write(cid, anum, lnum, item)
    _write(_action(cid, anum, lnum), item)
  end


  ###############################################
  # Read an Index
  #
  # @param cid [String] caseid
  # @param xnum [Integer] Index number
  # @param lnum [Integer] Log number
  # @return [String] the JSON encoded item
  #
  def index_read(cid, xnum, lnum)
    _read(_index(cid, xnum, lnum))
  end


  ###############################################
  # Write an Index
  #
  # @param cid [String] caseid
  # @param xnum [Integer] Index number
  # @param lnum [Integer] Log number
  # @param item [String] the JSON encoded item
  #
  def index_write(cid, xnum, lnum, item)
    _write(_index(cid, xnum, lnum), item)
  end


  ###############################################
  # Get a Tempfile to use to write files
  #
  # @return [Tempfile] a Tempfile which can be written and passed to
  #   #file_write
  #
  def tempfile; raise NotImplementedError; end


  private


  ###############################################
  # Read an item
  #
  def _read(path); raise NotImplementedError; end


  ###############################################
  # Write an item
  #
  def _write(path, item); raise NotImplementedError; end


  ###############################################
  # Path for case
  #
  def _case(cid, lnum)
    [
      @base,
      cid,
      'c'.freeze,
      '%d.json'.freeze % lnum
    ].join('/'.freeze)
  end


  ###############################################
  # Path for log
  #
  def _log(cid, lnum)
    [
      @base,
      cid,
      'l'.freeze,
      '%d.json'.freeze % lnum
    ].join('/'.freeze)
  end


  ###############################################
  # Path for entry
  #
  def _entry(cid, enum, lnum)
    [
      @base,
      cid,
      'e'.freeze,
      enum.to_s,
      '%d.json'.freeze % lnum
    ].join('/'.freeze)
  end


  ###############################################
  # Path for file
  #
  def _file(cid, enum, lnum, fnum)
    [
      @base,
      cid,
      'e'.freeze,
      enum.to_s,
      '%d-%d.bin'.freeze % [lnum, fnum]
    ].join('/'.freeze)
  end


  ###############################################
  # Filename for action
  #
  def _action(cid, anum, lnum)
    [
      @base,
      cid,
      'a'.freeze,
      anum.to_s,
      lnum.to_s + '.json'.freeze
    ].join('/'.freeze)
  end


  ###############################################
  # Filename for index
  #
  def _index(cid, xnum, lnum)
    [
      @base,
      cid,
      'i'.freeze,
      xnum.to_s,
      lnum.to_s + '.json'.freeze
    ].join('/'.freeze)
  end


end # class ICFS::Store

end # module ICFS
