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
# Stores current items and provides a standard search interface.
#
# Stores:
# * Case - current version
# * Log - all
# * Entry - current version
# * Action - current version
# * Current - for each case
# * Index - current version
#
# Provides locking and searching interface.
#
# @abstract
#
class Cache

  ###############################################
  # What searching options are supported
  #
  # @return [Hash] Supported searching options
  #
  def supports; raise NotImplementedError; end


  ###############################################
  # Take a case lock
  #
  # @param cid [String] caseid
  #
  def lock_take(cid); raise NotImplementedError; end


  ###############################################
  # Release a case lock
  #
  # @param cid [String] caseid
  #
  def lock_release(cid); raise NotImplementedError; end


  ###############################################
  # Read current
  #
  # @param cid [String] caseid
  # @return [String] JSON encoded item
  #
  def current_read(cid); raise NotImplementedError; end


  ###############################################
  # Write current
  #
  # @param cid [String] caseid
  # @param item [String] JSON encoded item
  #
  def current_write(cid, item); raise NotImplementedError; end


  ###############################################
  # Read a case
  #
  # @param cid [String] caseid
  # @return [String] JSON encoded item
  #
  def case_read(cid); raise NotImplementedError; end


  ###############################################
  # Write a case
  #
  # @param cid [String] caseid
  # @param item [String] JSON encoded item
  #
  def case_write(cid, item); raise NotImplementedError; end


  ###############################################
  # Search for cases
  #
  # @param query [Hash] the query
  #
  def case_search(query); raise NotImplementedError; end


  ###############################################
  # Get list of tags for cases
  #
  # @param query [Hash] the query
  #
  def case_tags(query); raise NotImplementedError;end


  ###############################################
  # Read an entry
  #
  # @param cid [String] caseid
  # @param enum [Integer] the entry number
  # @return [String] JSON encoded item
  #
  def entry_read(cid, enum); raise NotImplementedError; end


  ###############################################
  # Write an entry
  #
  # @param cid [String] caseid
  # @param enum [Integer] the entry number
  # @param item [String] JSON encoded item
  #
  def entry_write(cid, enum, item); raise NotImplementedError; end


  ###############################################
  # Search for entries
  #
  # @param query [Hash] the query
  #
  def entry_search(query); raise NotImplementedError; end


  ###############################################
  # List tags used on Entries
  #
  # @param query [Hash] the query
  #
  def entry_tags(query); raise NotImplementedError; end


  ###############################################
  # Read an action
  #
  # @param cid [String] caseid
  # @param anum [Integer] the action number
  # @return [String] JSON encoded item
  #
  def action_read(cid, anum); raise NotImplementedError; end


  ###############################################
  # Write an action
  #
  # @param cid [String] caseid
  # @param anum [Integer] the action number
  # @param item [String] JSON encoded item
  #
  def action_write(cid, anum, item); raise NotImplementedError; end


  ###############################################
  # Search for actions
  #
  # @param query [Hash] the query
  #
  def action_search(query); raise NotImplementedError; end


  ###############################################
  # List tags used on action tasks
  #
  # @param query [Hash] the query
  #
  def action_tags(query); raise NotImplementedError; end


  ###############################################
  # Read an Index
  #
  # @param cid [String] caseid
  # @param xnum [Integer] the index number
  # @return [String] JSON encoded item
  #
  def index_read(cid, xnum); raise NotImplementedError; end


  ###############################################
  # Write an Index
  #
  # @param cid [String] caseid
  # @param xnum [Integer] the index number
  # @param item [String] JSON encoded item
  #
  def index_write(cid, xnum, item); raise NotImplementedError; end


  ###############################################
  # Search for Indexes
  #
  # @param query [Hash] the query
  #
  def index_search(query); raise NotImplementedError; end


  ###############################################
  # List tags used in indexes
  #
  # @param query [Hash] the query
  #
  def index_tags(query); raise NotImplementedError; end


  ###############################################
  # Read a log
  #
  # @param cid [String] caseid
  # @param lnum [Integer] the log number
  # @return [String] JSON encoded item
  #
  def log_read(cid, lnum); raise NotImplementedError; end


  ###############################################
  # Write a log
  #
  # @param cid [String] caseid
  # @param lnum [Integer] the log number
  # @param item [String] JSON encoded item
  #
  def log_write(cid, lnum, item); raise NotImplementedError; end


  ###############################################
  # Search for a log
  #
  # @param query [Hash] the query
  #
  def log_search(query); raise NotImplementedError; end


  ###############################################
  # Analyze stats
  #
  # @param query [Hash] the query
  #
  def stats(query); raise NotImplementedError; end


end # class ICFS::Cache

end # module ICFS
