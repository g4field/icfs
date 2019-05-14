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
# Api
#
# @todo Add event logging
#
class Api

  # Validate a size
  ValSize = {
    method: :integer,
    min: 2,
    max: 100
  }.freeze


  # Validate a page
  ValPage = {
    method: :integer,
    min: 1,
    max: 10
  }.freeze


  # Validate a purpose
  ValPurpose = {
    method: :string,
    min: 1,
    max: 32,
    invalid: /[[:cntrl:]]/.freeze
  }.freeze


  ###############################################
  # New API
  #
  # @param stats [Array<String>] Global stats
  # @param users [Users] the User/role/group interface
  # @param cache [Cache] the cache
  # @param store [Store] the store
  #
  def initialize(stats, users, cache, store)
    @users = users
    @cache = cache
    @store = store
    @gstats = stats.map{|st| st.dup.freeze }.freeze
    reset
  end # def initialize


  ###############################################
  # Set the user
  #
  # @param uname [String] the user name
  #
  def user=(uname)
    @user = uname.dup.freeze
    urgp = @users.read(uname)
    raise(Error::NotFound, 'User name not found'.freeze) if !urgp
    raise(Error::Value, 'Not a user'.freeze) if urgp['type'] != 'user'
    @roles = urgp['roles'].each{|rn| rn.freeze }
    @groups = urgp['groups'].each{ |gn| gn.freeze }
    @perms = urgp['perms'].each{|pn| pn.freeze }

    @urg = Set.new
    @urg.add user
    @urg.merge roles
    @urg.merge groups
    @urg.freeze

    @ur = Set.new
    @ur.add user
    @ur.merge roles
    @ur.freeze

    reset
  end # def user=()


  ###############################################
  # User
  #
  attr_reader :user


  ###############################################
  # Roles
  #
  attr_reader :roles


  ###############################################
  # Groups
  #
  attr_reader :groups


  ###############################################
  # Global perms
  #
  attr_reader :perms


  ###############################################
  # Globals stats
  attr_reader :gstats


  ###############################################
  # User, Roles, Groups set
  #
  attr_reader :urg


  ###############################################
  # Reset the cached cases and access
  #
  def reset
    @cases = {}
    @access = {}
    @actions = {}
    @tasked = {}
  end


  ###############################################
  # Get a tempfile
  #
  def tempfile
    @store.tempfile
  end


  ###############################################
  # Get a stats list
  #
  # @param cid [String] caseid
  # @return [Set<String>] the stats, global and case
  # @raise [Error::NotFound] if case not found
  #
  def stats_list(cid)
    cse = case_read(cid)
    stats = Set.new
    stats.merge( cse['stats'] ) if cse['stats']
    stats.merge( @gstats )
    return stats
  end


  ###############################################
  # Get an access list
  #
  # @param cid [String] caseid
  # @return [Set<String>] the perms granted the user for this case
  # @raise [Error::NotFound] if case not found
  #
  def access_list(cid)
    if !@access.key?(cid)

      # get grants for the case
      cse = case_read(cid)
      al = Set.new
      cse['access'].each do |ac|
        gs = Set.new(ac['grant'])
        al.add(ac['perm']) if @urg.intersect?(gs)
      end

      # higher perms imply lower ones
      al.add(ICFS::PermRead) if al.include?(ICFS::PermManage)
      al.add(ICFS::PermWrite) if al.include?(ICFS::PermAction)
      al.add(ICFS::PermRead) if al.include?(ICFS::PermWrite)

      # merge in global perms
      al.merge @perms

      @access[cid] = al
    end
    return @access[cid]
  end # def access_list()


  ###############################################
  # See if we are tasked
  def _tasked?(cid, anum)
    id = '%s.%d'.freeze % [cid, anum]
    unless @tasked.key?(id)
      act = _action_read(cid, anum)

      tasked = false
      act['tasks'].each do |tk|
        if @ur.include?(tk['assigned'])
          tasked = true
          break
        end
      end

      @tasked[id] = tasked
    end

    return @tasked[id]
  end # def _tasked?()
  private :_tasked?


  ###############################################
  # Check if we can read an entry or action
  def _can_read?(cid, anum)

    # have read permission on the case or
    # are assigned to the action
    if access_list(cid).include?( ICFS::PermRead ) ||
       (anum && _tasked?(cid, anum) )
      return true
    else
      return false
    end

  end # def _can_read?()
  private :_can_read?



  ##############################################################
  # Read Items
  ##############################################################


  ###############################################
  # Read a case
  #
  # @param cid [String] caseid
  # @param lnum [Integer] log it was recorded
  # @return [Case] the case
  # @raise [Error::NotFound] if not case not found
  #
  def case_read(cid, lnum=0)
    if lnum != 0
      json = @store.case_read(cid, lnum)
      return Validate.parse(json, 'case'.freeze, Items::ItemCase)
    end

    if !@cases.key?(cid)
      json = @cache.case_read(cid)
      cur = Validate.parse(json, 'case'.freeze, Items::ItemCase)
      @cases[cid] = cur
    end
    return @cases[cid]
  end # end case_read()


  ###############################################
  # Read a log
  #
  # @param cid [String] caseid
  # @param lnum [Integer] log number
  # @raise [Error::NotFound] if log is not found
  # @raise [Error::Perms] if user does not have permissions
  #
  def log_read(cid, lnum)

    # get access list
    al = access_list(cid)
    if !al.include?(ICFS::PermRead)
      raise(Error::Perms, 'missing perms: %s'.freeze % ICFS::PermRead)
    end

    # read
    json = @cache.log_read(cid, lnum)
    return Validate.parse(json, 'log'.freeze, Items::ItemLog)
  end # def log_read()


  ###############################################
  # Read an entry
  #
  # @param cid [String] caseid
  # @param enum [Integer] the entry number
  # @param lnum [Integer] the log number or 0 for current
  # @raise [Error::NotFound] if it does not exist
  # @raise [Error::Perms] if user does not have permissions
  #
  def entry_read(cid, enum, lnum=0)

    # get access list and current entry
    al = access_list(cid)
    json = @cache.entry_read(cid, enum)
    ec = Validate.parse(json, 'entry'.freeze, Items::ItemEntry)

    # see if we can read the entry
    need = Set.new
    need.add( ICFS::PermRead ) unless _can_read?(cid, ec['action'] )
    need.merge(ec['perms']) if ec['perms']
    need.subtract(al)
    unless need.empty?
      raise(Error::Perms, 'missing perms: %s'.freeze %
        need.to_a.sort.join(', ') )
    end

    # return requested version
    if( lnum == 0 || ec['log'] == lnum )
      return ec
    else
      json = @store.entry_read(cid, enum, lnum)
      return Validate.parse(json, 'entry'.freeze, Items::ItemEntry)
    end
  end # def entry_read()


  ###############################################
  # Read a file
  #
  # @param cid [String] caseid
  # @param enum [Integer] the entry number
  # @param lnum [Integer] the log number
  # @param fnum [Integer] the file number
  # @raise [Error::NotFound] if it does not exist
  # @raise [Error::Perms] if user does not have permissions
  #
  def file_read(cid, enum, lnum, fnum)
    entry_read(cid, enum)
    fi = @store.file_read(cid, enum, lnum, fnum)
    raise(Error::NotFound, 'file not found'.freeze) if !fi
    return fi
  end # def file_read()


  ###############################################
  # Read an action
  #
  # Internal version.
  #
  def _action_read(cid, anum)
    id = '%s.%d'.freeze % [cid, anum]
    unless @actions.key?(id)
      json = @cache.action_read(cid, anum)
      act = Validate.parse(json, 'action'.freeze, Items::ItemAction)
      @actions[id] = act
    end
    return @actions[id]
  end # _action_read()
  private :_action_read


  ###############################################
  # Read an action
  #
  # @param cid [String] caseid
  # @param anum [Integer] the action number
  # @param lnum [Integer] the log number or 0 for current
  # @return [Action] requested action
  # @raise [Error::NotFound] if action is not found
  # @raise [Error::Perms] if user does not have permissions
  #
  def action_read(cid, anum, lnum=0)

    # get current action
    ac = _action_read(cid, anum)

    # see if we can read the action
    unless _can_read?(cid, anum)
      raise(Error::Perms, 'missing perms: %s'.freeze % ICFS::PermRead )
    end

    # return the requested version
    if( lnum == 0 || ac['log'] == lnum )
      return ac
    else
      json = @store.action_read( cid, anum, lnum)
      return Validate.parse(json, 'action'.freeze, Items::ItemAction)
    end
  end # def action_read()


  ###############################################
  # Read an index
  #
  # @param cid [String]
  # @param xnum [Integer] the index number
  # @param lnum [Integer] the log number
  # @raise [Error::NotFound] if it does not exist
  # @raise [Error::Perms] if user does not have permissions
  #
  def index_read(cid, xnum, lnum=0)

    # get access list
    al = access_list(cid)
    if !al.include?(ICFS::PermRead)
      raise(Error::Perms, 'missing perms: %s'.freeze % ICFS::PermRead )
    end

    # read curent index
    json = @cache.index_read(cid, xnum)
    xc = Validate.parse(json, 'index'.freeze, Items::ItemIndex)

    # return the requested version
    if( lnum == 0 || xc['log'] == lnum )
      return xc
    else
      json = @store.index_read(cid, xnum, lnum)
      return Validate.parse(json, 'index'.freeze, Items::ItemIndex)
    end
  end # def index_read()


  ###############################################
  # Read a current
  #
  # @param cid [String] caseid
  #
  def current_read(cid)

    al = access_list(cid)
    if !al.include?(ICFS::PermRead)
      raise(Error::Perms, 'missing perms: %s'.freeze % ICFS::PermRead)
    end

    json = @cache.current_read(cid)
    return Validate.parse(json, 'current'.current, Items::ItemCurrent)
  end # end def current_read()


  ##############################################################
  # Searches
  ##############################################################


  # Validate a case search query
  ValCaseSearch = {
    method: :hash,
    optional: {
      title: Items::FieldTitle,
      tags: Items::FieldTagAny,
      status: Validate::ValBoolean,
      template: Validate::ValBoolean,
      grantee: Items::FieldUsergrp,
      perm: Items::FieldPermAny,
      size: ValSize,
      page: ValPage,
      purpose: ValPurpose,
    }.freeze,
  }.freeze


  ###############################################
  # Search for a case
  #
  # @param query [Hash] a query
  #
  def case_search(query)
    Validate.validate(query, 'Case Search'.freeze, ValCaseSearch)
    @cache.case_search(query)
  end


  # Validate a log search
  ValLogSearch = {
    method: :hash,
    optional: {
      caseid: Items::FieldCaseid,
      after: Validate::ValIntPos,
      before: Validate::ValIntPos,
      user: Items::FieldUsergrp,
      entry: Validate::ValIntPos,
      index: Validate::ValIntPos,
      action: Validate::ValIntPos,
      size: ValSize,
      page: ValPage,
      purpose: ValPurpose,
      sort: {
        method: :string,
        allowed: Set[
          'time_desc'.freeze,
          'time_asc'.freeze,
        ].freeze,
        whitelist: true,
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # Search for a log
  #
  # @param query [Hash] a query
  #
  def log_search(query)
    Validate.validate(query, 'Log Search'.freeze, ValLogSearch)
    @cache.log_search(query)
  end


  # Validate an entry search query
  ValEntrySearch = {
    method: :hash,
    optional: {
      title: Items::FieldTitle,
      content: Items::FieldContent,
      tags: Items::FieldTagAny,
      caseid: Items::FieldCaseid,
      action: Validate::ValIntPos,
      index: Validate::ValIntPos,
      after: Validate::ValIntPos,
      before: Validate::ValIntPos,
      stat: Items::FieldStat,
      credit: Items::FieldUsergrp,
      size: ValSize,
      page: ValPage,
      purpose: ValPurpose,
      sort: {
        method: :string,
        allowed: Set[
          'time_desc'.freeze,
          'time_asc'.freeze,
        ].freeze,
        whitelist: true,
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # Search for entries
  #
  def entry_search(query)
    Validate.validate(query, 'Entry Search'.freeze, ValEntrySearch)

    # run the query
    res = @cache.entry_search(query)

    # check perms for each entry
    res[:list].each do |se|
      ent = se[:object]

      # can not read the case/action - basically nothing
      unless _can_read?(ent[:caseid], ent[:action])
        ent[:time] = nil
        ent[:title] = nil
        ent[:perms] = nil
        ent[:action] = nil
        ent[:tags] = nil
        ent[:files] = nil
        ent[:stats] = nil
        se[:snippet] = nil
        next
      end

      # can read the case/action, missing perms for this entry
      # leave time and perms
      al = access_list(ent[:caseid])
      if !(Set.new(ent[:perms]) - al).empty?
        ent[:title] = nil
        ent[:action] = nil
        ent[:tags] = nil
        ent[:files] = nil
        ent[:stats] = nil
        se[:snippet] = nil
      end
    end

    return res
  end # def entry_search()


  # Validate a task search
  ValActionSearch = {
    method: :hash,
    required: {
      assigned: {
        method: :any,
        check: [
          Items::FieldUsergrp,
          {
            method: :equals,
            check: ICFS::UserCase
          }
        ].freeze
      }.freeze
    }.freeze,
    optional: {
      caseid: Items::FieldCaseid,
      title: Items::FieldTitle,
      status: Validate::ValBoolean,
      flag: Validate::ValBoolean,
      before: Validate::ValIntPos,
      after: Validate::ValIntPos,
      tags: Items::FieldTagAny,
      size: ValSize,
      page: ValPage,
      purpose: ValPurpose,
      sort: {
        method: :string,
        allowed: Set[
          'time_desc'.freeze,
          'time_asc'.freeze,
        ].freeze,
        whitelist: true,
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # Search for actions
  #
  def action_search(query)
    Validate.validate(query, 'Action Search'.freeze, ValActionSearch)

    # only allow searches for user/roles you have
    unless @ur.include?(query[:assigned]) ||
       (query[:assigned] == ICFS::UserCase && query[:caseid] &&
          access_list(query[:caseid]).include?(ICFS::PermAction) )
      raise(Error::Perms, 'May not search for other\'s tasks'.freeze)
    end

    # run the search
    return @cache.action_search(query)
  end # def action_search()


  # Validate an index search query
  ValIndexSearch = {
    method: :hash,
    optional: {
      caseid: Items::FieldCaseid,
      title: Items::FieldTitle,
      prefix: Items::FieldTitle,
      content: Items::FieldContent,
      tags: Items::FieldTagAny,
      size: ValSize,
      page: ValPage,
      purpose: ValPurpose,
      sort: {
        method: :string,
        allowed: Set[
          'title_desc'.freeze,
          'title_asc'.freeze,
          'index_desc'.freeze,
          'index_asc'.freeze,
        ].freeze,
        whitelist: true,
      }.freeze
    }.freeze
  }.freeze


  ###############################################
  # Search for indexes
  #
  # @todo permissions checks?
  def index_search(query)
    Validate.validate(query, 'Index Search'.freeze, ValIndexSearch)
    @cache.index_search(query)
  end


  # validate the stats query
  ValStatsSearch = {
    method: :hash,
    optional: {
      caseid: Items::FieldCaseid,
      after: Validate::ValIntPos,
      before: Validate::ValIntPos,
      credit: Items::FieldUsergrp,
      purpose: ValPurpose,
    }.freeze
  }.freeze


  ###############################################
  # Analyze stats
  #
  # @todo permissions check?
  def stats(query)
    Validate.validate(query, 'Stats Search'.freeze, ValStatsSearch)
    @cache.stats(query)
  end

  # Case Tags search validation
  ValCaseTags = {
    method: :hash,
    optional: {
      status: Validate::ValBoolean,
      template: Validate::ValBoolean,
      grantee: Items::FieldUsergrp,
      purpose: ValPurpose,
    }.freeze,
  }.freeze


  ###############################################
  # Get case tags
  #
  def case_tags(query)
    Validate.validate(query, 'Case Tags Search'.freeze, ValCaseTags)
    return @cache.case_tags(query)
  end # def case_tags()


  # Entry Tags search validation
  ValEntryTags = {
    method: :hash,
    required: {
      caseid: Items::FieldCaseid,
    }.freeze,
    optional: {
      purpose: ValPurpose,
    }.freeze,
  }.freeze


  ###############################################
  # Get entry tags
  #
  def entry_tags(query)
    Validate.validate(query, 'Entry Tags Search'.freeze, ValEntryTags)
    al = access_list(query[:caseid])
    if !al.include?(ICFS::PermRead)
      raise(Error::Perms, 'missing perms: %s'.freeze % IFCS::PermRead)
    end
    return @cache.entry_tags(query)
  end # def entry_tags()


  # Task Tags search validation
  ValActionTags = {
    method: :hash,
    required: {
      assigned: {
        method: :any,
        check: [
          Items::FieldUsergrp,
          {
            method: :equals,
            check: ICFS::UserCase
          }.freeze
        ].freeze
      }.freeze,
    }.freeze,
    optional: {
      caseid: Items::FieldCaseid,
      status: Validate::ValBoolean,
      flag: Validate::ValBoolean,
      before: Validate::ValIntPos,
      after: Validate::ValIntPos,
      purpose: ValPurpose,
    }.freeze,
  }.freeze


  ###############################################
  # Get action tags
  #
  def action_tags(query)
    Validate.validate(query, 'Task Tags Search'.freeze, ValActionTags)

    # only allow searches for user/roles you have
    unless @ur.include?(query[:assigned]) ||
       (query[:assigned] == ICFS::UserCase && query[:caseid] &&
          access_list(query[:caseid]).include?(ICFS::PermAction) )
      raise(Error::Perms, 'May not search for other\'s tasks'.freeze)
    end

    # run the search
    return @cache.action_tags(query)
  end # def action_tags()


  # Validate a index tag search
  ValIndexTags = {
  method: :hash,
    required: {
      caseid: Items::FieldCaseid,
    }.freeze,
    optional: {
      purpose: ValPurpose,
    }.freeze
  }.freeze


  ###############################################
  # Get index tags
  #
  def index_tags(query)
    Validate.validate(query, 'Index Tags'.freeze, ValIndexTags)
    al = access_list(query[:caseid])
    if !al.include?(ICFS::PermRead)
      raise(Error::Perms, 'missing perms: %s'.freeze % ICFS::PermRead)
    end
    return @cache.index_tags(query)
  end


  ##############################################################
  # Record
  ##############################################################


  ###############################################
  # Create a new case
  #
  # @param ent [Hash] the first entry
  # @param cse [Hash] the case
  # @param tid [String] the template name
  #
  def case_create(ent, cse, tid=nil)

    ####################
    # Sanity checks

    # form & values
    Validate.validate(ent, 'entry'.freeze, Items::ItemEntryNew)
    Validate.validate(cse, 'case'.freeze, Items::ItemCaseEdit)

    # access users/roles/groups are valid
    cse["access"].each do |acc|
      acc["grant"].each do |gnt|
        urg = @users.read(gnt)
        if !urg
          raise(Error::NotFound, 'User/role/group %s not found'.freeze % urg)
        end
      end
    end

    # permissions
    perms = Set[ ICFS::PermManage ]
    perms.merge(ent['perms']) if ent['perms']

    # template
    if tid
      tmpl = case_read(tid)
      unless tmpl['template']
        raise(Error::Perms, 'Not a template'.freeze)
      end

      al = access_list(tid)
      unless al.include?(ICFS::PermManage)
        raise(Error::Perms, 'May not create cases from this template'.freeze)
      end
    end

    # no action/indexes
    if ent['action']
      raise(Error::Value, 'No Action for a new case entry'.freeze)
    end
    if ent['index']
      raise(Error::Value, 'No Index for a new case entry'.freeze)
    end


    ####################
    # Prep

    # case
    cid = ent['caseid']
    cse['icfs'] = 1
    cse['caseid'] = cid
    cse['log'] = 1
    cse['tags'] ||= [ ICFS::TagNone ]
    citem = Validate.generate(cse, 'case'.freeze, Items::ItemCase)

    # entry
    ent['icfs'] = 1
    ent['entry'] = 1
    ent['log'] = 1
    ent['tags'] ||= [ ]
    ent['tags'] << ICFS::TagCase
    ent['user'] = @user
    files, fhash = _pre_files(ent)

    # log
    log = {
      'icfs' => 1,
      'caseid' => cid,
      'log' => 1,
      'prev' => '0'*64,
      'user' => @user,
      'entry' => {
        'num' => 1,
       },
       'case_hash' => ICFS.hash(citem),
    }
    log['files_hash'] = fhash if fhash

    # current
    cur = {
      'icfs' => 1,
      'caseid' => cid,
      'log' => 1,
      'entry' => 1,
      'action' => 0,
      'index' => 0
    }

    ####################
    # Write the case

    # take lock
    @cache.lock_take(cid)
    begin
      if @cache.case_read(cid)
        raise(Error::Conflict, 'Case already exists'.freeze)
      end

      now = Time.now.to_i

      # finish items
      ent['time'] ||= now
      ent['files'].each{|fi| fi['log'] ||= 1 } if ent['files']
      eitem = Validate.generate(ent, 'entry'.freeze, Items::ItemEntry)
      log['time'] = now
      log['entry']['hash'] = ICFS.hash(eitem)
      litem = Validate.generate(log, 'log'.freeze, Items::ItemLog)
      cur['hash'] = ICFS.hash(litem)
      nitem = Validate.generate(cur, 'current'.freeze, Items::ItemCurrent)

      # write to cache
      @cache.entry_write(cid, 1, eitem)
      @cache.log_write(cid, 1, litem)
      @cache.case_write(cid, citem)
      @cache.current_write(cid, nitem)

      # write to store
      @store.entry_write(cid, 1, 1, eitem)
      @store.log_write(cid, 1, litem)
      @store.case_write(cid, 1, citem)

    # release lock
    ensure
      @cache.lock_release(cid)
    end

    # files
    files.each_index{|ix| @store.file_write(cid, 1, 1, ix+1, files[ix]) }

  end # def case_create()


  ###############################################
  # Write items to a case
  #
  # @param ent [Hash] Entry to record, required
  # @param act [Hash, Nilclass] Action to record, optional
  # @param idx [Hash, Nilclass] Index to record, optional
  # @param cse [Hash, Nilclass] Case to record, optional
  #
  def record(ent, act, idx, cse)

    ####################
    # Sanity checks

    # form & content
    if idx || cse
      Validate.validate(ent, 'New Entry'.freeze, Items::ItemEntryNew)
    else
      Validate.validate(ent, 'Editable Entry'.freeze, Items::ItemEntryEdit)
    end
    Validate.validate(act, 'action'.freeze, Items::ItemActionEdit) if act
    Validate.validate(idx, 'index'.freeze, Items::ItemIndexEdit) if idx
    Validate.validate(cse, 'case'.freeze, Items::ItemCaseEdit) if cse

    # edit index OR case, not both
    if idx && cse
      raise(Error::Value, 'May not edit both case and index at once'.freeze)
    end

    # no changing the action
    if act && ent['action'] && act['action'] && act['action'] != ent['action']
      raise(Error::Conflict, 'May not change entry\'s action'.freeze)
    end

    # access users/roles/groups are valid
    if cse
      cse['access'].each do |acc|
        acc['grant'].each do |gnt|
          urg = @users.read(gnt)
          if !urg
            raise(Error::NotFound, 'User/role/group %s not found'.freeze % gnt)
          end
        end
      end
    end

    # tasking users/roles are valid
    if act
      act['tasks'].each_index do |ix|
        next if ix == 0
        tsk = act['tasks'][ix]
        ur = @users.read(tsk['assigned'])
        if !ur
          raise(Error::NotFound, 'User/role %s not found'.freeze %
             tsk['assigned'])
        end
        type = ur['type']
        if type != 'user' && type != 'role'
          raise(Error::Values, 'Not a user or role: %s'.freeze %
             tsk['assigned'])
        end
      end
    end


    ####################
    # Prep
    cid = ent['caseid']

    # entry
    ent['icfs'] = 1
    ent['tags'] ||= [ ]
    ent['user'] = @user
    files, fhash = _pre_files(ent)

    # action
    if act
      ent['tags'] << ICFS::TagAction
      act['icfs'] = 1
      act['caseid'] = cid
      act['tasks'].each do |tk|
        tk['tags'] ||= [ ICFS::TagNone ]
      end
    end

    # index
    if idx
      ent['tags'] << ICFS::TagIndex
      idx['icfs'] = 1
      idx['caseid'] = cid
      idx['tags'] ||= [ ICFS::TagNone ]
    end

    # case
    if cse
      ent['tags'] << ICFS::TagCase
      cse['icfs'] = 1
      cse['caseid'] = cid
      cse['tags'] ||= [ ICFS::TagNone ]
    end

    # log
    log = {
      'icfs' => 1,
      'caseid' => cid,
      'user' => @user,
    }
    log['files_hash'] = fhash if fhash

    # no tags
    ent['tags'] = [ ICFS::TagNone ] if ent['tags'].empty?

    # current
    nxt = {
      'icfs' => 1,
      'caseid' => cid,
    }


    ####################
    # Write

    # take lock
    @cache.lock_take(cid)
    begin
      now = Time.now.to_i

      ####################
      # get prior items & numbers

      # current
      json = @cache.current_read(cid)
      cur = Validate.parse(json, 'current'.freeze, Items::ItemCurrent)

      # entry
      if ent['entry']
        enum = ent['entry']
        json = @cache.entry_read(cid, enum)
        ent_pri = Validate.parse(json, 'entry'.freeze, Items::ItemEntry)
        nxt['entry'] = cur['entry']
      else
        enum = cur['entry'] + 1
        nxt['entry'] = enum
      end

      # action
      if ent_pri && ent_pri['action']
        anum = ent_pri['action']
      elsif act && act['action']
        anum = act['action']
      end
      if anum
        json = @cache.action_read(cid, anum)
        act_pri = Validate.parse(json, 'action'.freeze, Items::ItemAction)
        nxt['action'] = cur['action']
      elsif act
        anum = cur['action'] + 1
        nxt['action'] = anum
      else
        nxt['action'] = cur['action']
      end

      # index
      if idx
        if idx['index']
          xnum = idx['index']
          nxt['index'] = cur['index']
        else
          xnum = cur['index'] + 1
          nxt['index'] = xnum
        end
      else
        xnum = nil
        nxt['index'] = cur['index']
      end

      # case
      cse_pri = case_read(cid)
      al = access_list(cid)

      # log
      lnum = cur['log'] + 1
      nxt['log'] = lnum


      ####################
      # Checks
      perms = Set.new

      # entry
      perms.merge(ent['perms']) if ent['perms']
      if ent_pri

        # must have those perms
        perms.add(ent_pri['perms']) if ent_pri['perms']

        # may not change action
        if ent_pri['action'] && (ent['action'] != ent_pri['action'])
          raise(Error::Conflict, 'May not change entry\'s action'.freeze)
        end

        # may not remove or add action, index, case tags
        if( (ent_pri['tags'].include?(ICFS::TagAction) !=
                 ent['tags'].include?(ICFS::TagAction) ) ||
            (ent_pri['tags'].include?(ICFS::TagIndex) !=
                 ent['tags'].include?(ICFS::TagIndex) ) ||
            (ent_pri['tags'].include?(ICFS::TagCase) !=
                 ent['tags'].include?(ICFS::TagCase) ) )
          raise(Error::Conflict, 'May not change entry\'s special tags'.freeze)
        end
      end

      # action
      if act
        pri_tsk = act_pri ? act_pri['tasks'] : []
        cur_tsk = act['tasks']
        act_open = cur_tsk[0]['status']

        # not allowed to delete tasks
        if pri_tsk.size > cur_tsk.size
          raise(Error::Conflict, 'May not delete tasks'.freeze)
        end

        # check each task
        perm_act = al.include?(ICFS::PermAction)
        tasked = false
        cur_tsk.each_index do |ix|
          ct = cur_tsk[ix]
          pt = pri_tsk[ix]

          # may not delete a tasking
          if pt && pt['assigned'] != ct['assigned']
            raise(Error::Conflict, 'May not delete task'.freeze)
          end

          # new taskings require action to be open
          if !pt && !act_open
            raise(Error::Value, 'New tasks require the action be open'.freeze)
          end

          # may not have a task open if action is closed
          if ct['status'] && !act_open
            raise(Error::Value, 'Open tasks on closed action'.freeze)
          end

          # can set any values for our tasks
          if @ur.include?(ct['assigned']) || (ix == 0 && perm_act )
            tasked = true
            next
          end

          # must be flagged if new tasking or re-opening
          if !ct['flag'] && (!pt || (ct['status'] && !pt['status']))
            raise(Error::Value, 'New or re-opened taskings must flag'.freeze)
          end

          # no changing other's taskings, no deflagging, and no
          # closing task without action
          if pt && (
             (pt['title'] != ct['title']) || (pt['time'] != ct['time']) ||
             (pt['tags'] != ct['tags']) || (pt['flag'] && !ct['flag']) ||
             (pt['status'] && !ct['status'] && !perm_act) )
            raise(Error::Value, 'May not change other\'s tasks'.freeze)
          end
        end

        # new tasks or changes to other's tasks
        if !act_pri || !tasked
          perms.add( ICFS::PermAction )
        end

      end

      # no checks for index

      # case
      if cse
        # no changing template
        unless cse['template'] == cse_pri['template']
          raise(Error::Conflict, 'May not change template status'.freeze)
        end

        # manage required
        perms.add( ICFS::PermManage ) if cse
      end

      # write unless a case or pre-existing action
      unless cse || act_pri
        perms.add( ICFS::PermWrite)
      end

      # permissions
      perms_miss = perms - al
      unless perms_miss.empty?
        raise(Error::Perms, 'Missing perms: %s'.freeze %
          perms_miss.to_a.sort.join(', ') )
      end


      ####################
      # Items

      # entry
      ent['entry'] = enum
      ent['log'] = lnum
      ent['time'] ||= now
      ent['action'] = anum if act
      if idx
        if ent['index']
          ent['index'] = ent['index'].push(xnum).uniq.sort
        else
          ent['index'] = [ xnum ]
        end
      end
      ent['files'].each{|fi| fi['log'] ||= lnum } if ent['files']
      eitem = Validate.generate(ent, 'entry'.freeze, Items::ItemEntry)
      log['entry'] = {
        'num' => enum,
        'hash' => ICFS.hash(eitem)
      }

      # action
      if act
        act['action'] = anum
        act['log'] = lnum
        aitem = Validate.generate(act, 'action'.freeze, Items::ItemAction)
        log['action'] = {
          'num' => anum,
          'hash' => ICFS.hash(aitem)
        }
      end

      # index
      if idx
        idx['index'] = xnum
        idx['log'] = lnum
        xitem = Validate.generate(idx, 'index'.freeze, Items::ItemIndex)
        log['index'] = {
          'num' => xnum,
          'hash' => ICFS.hash(xitem)
        }
      end

      # case
      if cse
        cse['log'] = lnum
        citem = Validate.generate(cse, 'case'.freeze, Items::ItemCase)
        log['case_hash'] = ICFS.hash(citem)
      end

      # log
      log['log'] = lnum
      log['prev'] = cur['hash']
      log['time'] = now
      litem = Validate.generate(log, 'log'.freeze, Items::ItemLog)
      nxt['hash'] = ICFS.hash(litem)

      # next
      nitem = Validate.generate(nxt, 'current'.freeze, Items::ItemCurrent)


      ####################
      # Write

      # entry
      @cache.entry_write(cid, enum, eitem)
      @store.entry_write(cid, enum, lnum, eitem)

      # action
      if act
        @cache.action_write(cid, anum, aitem)
        @store.action_write(cid, anum, lnum, aitem)
      end

      # index
      if idx
        @cache.index_write(cid, xnum, xitem)
        @store.index_write(cid, xnum, lnum, xitem)
      end

      # case
      if cse
        @cache.case_write(cid, citem)
        @store.case_write(cid, lnum, citem)
      end

      # log
      @cache.log_write(cid, lnum, litem)
      @store.log_write(cid, lnum, litem)

      # current
      @cache.current_write(cid, nitem)

    # release the lock
    ensure
      @cache.lock_release(cid)
    end

    # write the files
    files.each_index{|ix| @store.file_write(cid, enum, lnum, ix+1, files[ix]) }

  end # def record()


  ###############################################
  # Assemble files before taking the lock
  #
  def _pre_files(ent)

    files = []
    if ent.key?('files')
      fhash = []
      ent['files'].each do |at|
        if at.key?('temp')
          fi = at['temp']
          at.delete('temp')
          files << fi
          at['num'] = files.size
          fhash << ICFS.hash_temp(fi)
        end
      end
    end

    return [files, fhash]
  end # def _pre_files()
  private :_pre_files


end # class ICFS::Api

end # module ICFS
