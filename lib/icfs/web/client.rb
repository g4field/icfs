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

require 'rack'

module ICFS

##########################################################################
# Web interface using Rack
#
module Web

##########################################################################
# Web Client
#
# @todo Improve time handling for web interface
# @todo Scrub the javascript
#
class Client

  ###############################################
  # New instance
  #
  # @param css [String] the URL for the stylesheet
  # @param js [String] the URL for the javascript
  #
  def initialize(css, js)
    @css = css.freeze
    @js = js.freeze
  end


  ###############################################
  # A Rack call
  #
  # @param env [Hash] the Rack environment
  #
  def call(env)

    # grab the path components
    path = env['PATH_INFO']
    if path.empty?
      cmps = ['']
    else
      cmps = path.split('/'.freeze, -1)
      cmps.shift if cmps[0].empty?
      cmps = [''] if cmps.empty?
    end
    env['icfs.cmps'] = cmps

    # reset
    env['icfs'].reset

    case cmps[0]

    # search
    when 'case_search'
      return _call_search(env,
        'Case Search'.freeze,
        'Case Search'.freeze,
        QueryCase,
        ListCase,
        :case_search,
        Proc.new{|qu, txt| _a_case_search(env, qu, txt) }
      )

    when 'entry_search'
      return _call_search(env,
        'Entry Search'.freeze,
        'Entry Search'.freeze,
        QueryEntry,
        ListEntry,
        :entry_search,
        Proc.new{|qu, txt| _a_entry_search(env, qu, txt) }
      )

    when 'log_search'
      return _call_search(env,
        'Log Search'.freeze,
        'Log Search'.freeze,
        QueryLog,
        ListLog,
        :log_search,
        Proc.new{|qu, txt| _a_log_search(env, qu, txt) }
      )

    when 'action_search'
      return _call_search(env,
        'Action Search'.freeze,
        'Action Search'.freeze,
        QueryAction,
        ListAction,
        :action_search,
        Proc.new{|qu, txt| _a_action_search(env, qu, txt) }
      )

    when 'index_search'
      return _call_search(env,
        'Index Search'.freeze,
        'Index Search'.freeze,
        QueryIndex,
        ListIndex,
        :index_search,
        Proc.new{|qu, txt| _a_index_search(env, qu, txt) }
      )

    when 'index_lookup'; return _call_index_lookup(env)

    # aggregations
    when 'stats'
      return _call_search(env,
        'Stats Search'.freeze,
        'Stats Search'.freeze,
        QueryStats,
        ListStats,
        :stats,
        nil
      )

    when 'case_tags'
      return _call_search(env,
        'Case Tags'.freeze,
        'Case Tags Search'.freeze,
        QueryCaseTags,
        ListCaseTags,
        :case_tags,
        nil
      )

    when 'entry_tags'
      return _call_search(env,
        'Entry Tags'.freeze,
        'Entry Tag Search'.freeze,
        QueryEntryTags,
        ListEntryTags,
        :entry_tags,
        nil
      )

    when 'action_tags'
      return _call_search(env,
        'Action Tags'.freeze,
        'Action Tag Search'.freeze,
        QueryActionTags,
        ListActionTags,
        :action_tags,
        nil
      )

    when 'index_tags'
      return _call_search(env,
        'Index Tags'.freeze,
        'Index Tag Search'.freeze,
        QueryIndexTags,
        ListIndexTags,
        :index_tags,
        nil
      )

    # forms
    when 'case_create'; return _call_case_create(env)
    when 'case_edit'; return _call_case_edit(env)
    when 'entry_edit'; return _call_entry_edit(env)
    when 'index_edit'; return _call_index_edit(env)

    # view
    when 'home', ''; return _call_home(env)
    when 'case'; return _call_case(env)
    when 'entry'; return _call_entry(env)
    when 'log'; return _call_log(env)
    when 'action'; return _call_action(env)
    when 'index'; return _call_index(env)
    when 'file'; return _call_file(env)

    # info page
    when 'info'; return _call_info(env)

    # not supported path
    else
      env['icfs.page'] = 'Invalid'.freeze
      raise(Error::NotFound, 'Invalid request'.freeze)
    end

  rescue Error::NotFound => e
    return _resp_notfound( env, 'Not found: %s'.freeze %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Perms => e
    return _resp_forbidden( env, 'Forbidden: %s'.freeze %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Conflict => e
    return _resp_conflict( env, 'Conflict: %s'.freeze %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Value => e
    return _resp_badreq( env, 'Invalid values: %s'.freeze %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Interface => e
    return _resp_badreq(env, Rack::Utils.escape_html(e.message))

  end # def call()

  private


###########################################################
# Handle calls
###########################################################

  ###############################################
  # Info page
  def _call_info(env)
    env['icfs.page'] = 'Info'.freeze
    api = env['icfs']
    _verb_get(env)
    body = [
      _div_nav(env),
      _div_desc('Info'.freeze, ''.freeze),
      _div_info(env)
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_info()


  ###############################################
  # Common search, tags, stats code
  #
  def _call_search(env, page, type, query_get,
    list, api_meth, page_proc)
    env['icfs.page'] = page
    api = env['icfs']
    _verb_get(env)
    act = '%s/%s'.freeze % [env['SCRIPT_NAME'], env['icfs.cmps'][0]]

    # form
    if env['QUERY_STRING'].empty?
      body = [
        _div_nav(env),
        _div_desc(type, ''.freeze),
        _form_query(env, query_get, {}, act, true)
      ]

    # do the query
    else
      query = _util_get_query(env, query_get)
      resp = api.send(api_meth, query)
      if query[:caseid]
        env['icfs.cid' ] = query[:caseid]
      end
      body = [
        _div_nav(env),
        _div_query(env, type, query_get, resp[:query]),
        _form_query(env, query_get, resp[:query], act),
        _div_list(env, resp, list),
      ]
      if page_proc
        body << _div_page(resp, page_proc)
      end
    end

    return _resp_success(env, body.join(''.freeze))
  end # def _call_search()


  ###############################################

  # Case query options
  QueryCase = [
    ['title'.freeze, :title, :string].freeze,
    ['tags'.freeze, :tags, :string].freeze,
    ['status'.freeze, :status, :boolean].freeze,
    ['template'.freeze, :template, :boolean].freeze,
    ['grantee'.freeze, :grantee, :string].freeze,
    ['perm'.freeze, :perm, :string].freeze,
    ['size'.freeze, :size, :integer].freeze,
    ['page'.freeze, :page, :integer].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # List case search
  ListCase = [
    [:caseid, :current].freeze,
    [:tags, nil].freeze,
    [:title, :case].freeze,
    [:snippet, nil].freeze
  ].freeze


  # Entry query options
  QueryEntry = [
    ['title'.freeze, :title, :string].freeze,
    ['content'.freeze, :content, :string].freeze,
    ['tags'.freeze, :tags, :string].freeze,
    ['caseid'.freeze, :caseid, :string].freeze,
    ['action'.freeze, :action, :integer].freeze,
    ['after'.freeze, :after, :time].freeze,
    ['before'.freeze, :before, :time].freeze,
    ['stat'.freeze, :stat, :string].freeze,
    ['credit'.freeze, :credit, :string].freeze,
    ['size'.freeze, :size, :integer].freeze,
    ['page'.freeze, :page, :integer].freeze,
    ['sort'.freeze, :sort, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Entry query display
  ListEntry = [
    [:caseid, :mixed].freeze,
    [:entry, :current].freeze,
    [:action, :current].freeze,
    [:time, :entry].freeze,
    [:tags, nil].freeze,
    [:index, :entry].freeze,
    [:files, nil].freeze,
    [:stats, nil].freeze,
    [:title, :entry].freeze,
    [:snippet, nil].freeze,
  ].freeze


  # Log query options
  QueryLog = [
    ['caseid'.freeze, :caseid, :string].freeze,
    ['after'.freeze, :after, :time].freeze,
    ['before'.freeze, :before, :time].freeze,
    ['user'.freeze, :user, :string].freeze,
    ['entry'.freeze, :entry, :integer].freeze,
    ['index'.freeze, :index, :integer].freeze,
    ['action'.freeze, :action, :integer].freeze,
    ['size'.freeze, :size, :integer].freeze,
    ['page'.freeze, :page, :integer].freeze,
    ['sort'.freeze, :sort, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Log query display
  ListLog = [
    [:caseid, :mixed].freeze,
    [:log, nil].freeze,
    [:time, :log].freeze,
    [:user, nil].freeze,
    [:entry, :log].freeze,
    [:action, :log].freeze,
    [:index, :log].freeze,
  ].freeze


  # Task query options
  QueryAction = [
    ['assigned'.freeze, :assigned, :string].freeze,
    ['caseid'.freeze, :caseid, :string].freeze,
    ['title'.freeze, :title, :string].freeze,
    ['status'.freeze, :status, :boolean].freeze,
    ['flag'.freeze, :flag, :boolean].freeze,
    ['before'.freeze, :before, :time].freeze,
    ['after'.freeze, :after, :time].freeze,
    ['tags'.freeze, :tags, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
    ['size'.freeze, :size, :integer].freeze,
    ['page'.freeze, :page, :integer].freeze,
    ['sort'.freeze, :sort, :string].freeze,
  ].freeze


  # Task list options
  ListAction = [
    [:time, nil].freeze,
    [:tags, nil].freeze,
    [:caseid, :mixed].freeze,
    [:title, :action].freeze,
    [:snippet, nil].freeze,
  ].freeze



  ###############################################
  # Do an index lookup
  #
  def _call_index_lookup(env)
    env['icfs.page'] = 'Index Lookup'.freeze
    api = env['icfs']
    _verb_get(env)

    # query required
    if env['QUERY_STRING'].empty?
      raise(Error::Interface, 'Query string required'.freeze)
    end

    # do the query
    query = _util_get_query(env, QueryIndex)
    resp = api.index_search(query)
    first = resp[:list][0]

    # raw rack return
    if first
      body = {
        'index' => first[:object][:index],
        'title' => first[:object][:title],
      }
    else
      body = {
        'index' => nil
      }
    end
    body = JSON.generate(body)
    head = {
      'Content-Type' => 'application/json'.freeze,
      'Content-Length' => body.bytesize.to_s
    }
    return [200, head, [body]]
  end # def _call_index_lookup()


  # Index query options
  QueryIndex = [
    ['caseid'.freeze, :caseid, :string].freeze,
    ['title'.freeze, :title, :string].freeze,
    ['prefix'.freeze, :prefix, :string].freeze,
    ['content'.freeze, :content, :string].freeze,
    ['tags'.freeze, :tags, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
    ['size'.freeze, :size, :integer].freeze,
    ['page'.freeze, :page, :integer].freeze,
    ['sort'.freeze, :sort, :string].freeze,
  ].freeze


  # Task list options
  ListIndex = [
    [:caseid, :mixed].freeze,
    [:index, :current].freeze,
    [:title, :index].freeze,
    [:snippet, nil].freeze,
  ].freeze


  # Stats query options
  QueryStats = [
    ['credit'.freeze, :credit, :string].freeze,
    ['caseid'.freeze, :caseid, :string].freeze,
    ['before'.freeze, :before, :time].freeze,
    ['after'.freeze, :after, :time].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze

  # Stats list options
  ListStats = [
    [:stat, nil].freeze,
    [:count, nil].freeze,
    [:sum, nil].freeze,
  ].freeze


  # Query for case tags
  QueryCaseTags = [
    ['status'.freeze, :status, :boolean].freeze,
    ['template'.freeze, :template, :boolean].freeze,
    ['grantee'.freeze, :grantee, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Case Tags list
  ListCaseTags = [
    [:tag, :case].freeze,
    [:count, nil].freeze,
  ].freeze


  # Entry tags query options
  QueryEntryTags = [
    ['caseid'.freeze, :caseid, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Entry Tags list
  ListEntryTags = [
    [:tag, :entry].freeze,
    [:count, nil].freeze,
  ].freeze


  # Action Tag query
  QueryActionTags = [
    ['caseid'.freeze, :caseid, :string].freeze,
    ['assigned'.freeze, :assigned, :string].freeze,
    ['status'.freeze, :status, :boolean].freeze,
    ['flag'.freeze, :flag, :boolean].freeze,
    ['before'.freeze, :before, :time].freeze,
    ['after'.freeze, :after, :time].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Action Tags list
  ListActionTags = [
    [:tag, :action].freeze,
    [:count, nil].freeze
  ].freeze


  # Index tags query
  QueryIndexTags = [
    ['caseid'.freeze, :caseid, :string].freeze,
    ['purpose'.freeze, :purpose, :string].freeze,
  ].freeze


  # Index tags list
  ListIndexTags = [
    [:tag, :index].freeze,
    [:count, nil].freeze,
  ].freeze


  ###############################################
  # Create a new case
  #
  def _call_case_create(env)
    env['icfs.page'] = 'Case Create'.freeze
    api = env['icfs']
    tid = _util_case(env)
    _verb_getpost(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'.freeze
      tpl = api.case_read(tid)
      tpl['title'] = ''.freeze
      parts = [
        _form_entry(env, tid, nil),
        _form_create(env),
        _form_case(env, tpl),
      ]
      body = [
        _div_nav(env),
        _div_desc(
          'Create New Case'.freeze,
          '<i>template:</i> %s'.freeze % Rack::Utils.escape_html(tid),
        ),
        _div_form(env, '/case_create/'.freeze, tid, parts, 'Create Case'.freeze)
      ].join(''.freeze)
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'.freeze
      para = _util_post(env)

      # process
      cse = _post_case(env, para)
      cid =  para['create_cid']
      cse['template'] = (para['create_tmpl'] == 'true'.freeze) ? true : false

      # process entry
      ent = _post_entry(env, para)
      Items.validate(tid, 'Template ID'.freeze, Items::FieldCaseid)
      ent['caseid'] = cid

      # create
      api.case_create(ent, cse, tid)

      # display the new case
      env['icfs.cid'] = cid
      body = _div_nav(env) + _div_case(env, cse)
      return _resp_success(env, body)
    end
  end # def _call_case_create()


  ###############################################
  # Edit a case
  #
  def _call_case_edit(env)
    env['icfs.page'] = 'Case Edit'.freeze
    cid = _util_case(env)
    api = env['icfs']
    _verb_getpost(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'.freeze
      cse = api.case_read(cid)
      parts = [
        _form_entry(env, cid, nil),
        _form_case(env, cse),
      ]
      body = [
        _div_nav(env),
        _div_desc('Edit Case'.freeze, ''.freeze),
        _div_form(env, '/case_edit/'.freeze, cid, parts, 'Record Case'.freeze),
      ].join(''.freeze)
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'.freeze
      para = _util_post(env)

      # process
      cse = _post_case(env, para)
      ent = _post_entry(env, para)
      act = _post_action(env, para)
      if act.is_a?(Integer)
        ent['action'] = act if act != 0
        act = nil
      end
      ent['caseid'] = cid
      cse_old = api.case_read(cid)
      cse['template'] = cse_old['template']
      api.record(ent, act, nil, cse)

      # display the case
      body = _div_nav(env) + _div_case(env, cse)
      return _resp_success(env, body)
    end
  end # def _call_case_edit()


  ###############################################
  # Edit an entry
  #
  def _call_entry_edit(env)
    env['icfs.page'] = 'Entry Edit'.freeze
    api = env['icfs']
    _verb_getpost(env)

    cid = _util_case(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'.freeze
      enum = _util_num(env, 2)
      anum = _util_num(env, 3)

      # entry or action specified
      if enum != 0
        desc = 'Edit Entry'.freeze
        ent = api.entry_read(cid, enum)
      elsif anum != 0
        desc = 'New Entry in Action'.freeze
        act = api.action_read(cid, anum)
      else
        desc = 'New Entry'.freeze
      end

      # see if editing is possible
      unless( api.access_list(cid).include?(ICFS::PermWrite) || (
        (anum != 0) && api.tasked?(cid, anum)))
        raise(Error::Perms, 'Not able to edit this entry.'.freeze)
      end

      # build form
      parts = [ _form_entry(env, cid, ent) ]
      if !ent &&
         (act || api.access_list(cid).include?(ICFS::PermAction))
        parts <<  _form_action(env, cid, act, {edit: false})
      end
      body = [
        _div_nav(env),
        _div_desc(desc, ''.freeze),
        _div_form(env, '/entry_edit/'.freeze, cid, parts,
          'Record Entry'.freeze),
      ].join(''.freeze)
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'.freeze
      para = _util_post(env)

      # process
      ent = _post_entry(env, para)
      act = _post_action(env, para)
      if act.is_a?(Integer)
        ent['action'] = act if act != 0
        act = nil
      end
      ent['caseid'] = cid
      api.record(ent, act, nil, nil)

      # display the entry
      body = [
        _div_nav(env),
        _div_entry(env, ent)
      ]
      body << _div_action(env, act) if act
      return _resp_success(env, body.join(''.freeze))
    end
  end # def _call_entry_edit()


  ###############################################
  # Edit an Index
  #
  def _call_index_edit(env)
    env['icfs.page'] = 'Index Edit'.freeze
    api = env['icfs']
    _verb_getpost(env)

    cid = _util_case(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'.freeze

      # see if editing is possible
      unless api.access_list(cid).include?(ICFS::PermWrite)
        raise(Error::Perms, 'Not able to edit this index.'.freeze)
      end

      xnum = _util_num(env, 2)
      idx = api.index_read(cid, xnum) if xnum != 0
      parts = [
        _form_entry(env, cid, nil),
        _form_index(env, cid, idx),
      ]
      desc = idx ? 'Edit Index'.freeze : 'New Index'.freeze
      body = [
        _div_nav(env),
        _div_desc(desc, ''.freeze),
        _div_form(env, '/index_edit/'.freeze, cid, parts,
          'Record Index'.freeze),
      ].join(''.freeze)
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'.freeze
      para = _util_post(env)

      # process
      ent = _post_entry(env, para)
      act = _post_action(env, para)
      idx = _post_index(env, para)
      if act.is_a?(Integer)
        ent['action'] = act if act != 0
        act = nil
      end
      ent['caseid'] = cid
      api.record(ent, act, idx, nil)

      # display the index
      body = [
        _div_nav(env),
        _div_entry(env, ent),
        _div_index(env, idx)
      ].join(''.freeze)
      return _resp_success(env, body)
    end
  end # def _call_index_edit()


  ###############################################
  # User Home page
  def _call_home(env)
    env['icfs.page'] = 'Home'.freeze
    _verb_get(env)
    body = [
      _div_nav(env),
      _div_desc('User Home'.freeze, ''.freeze),
      _div_home(env),
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_home()


  ###############################################
  # Display a Case
  #
  def _call_case(env)
    env['icfs.page'] = 'Case View'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    lnum = _util_num(env, 2)
    cse = api.case_read(cid, lnum)
    if lnum != 0
      msg = 'This is a historical version of this Case'.freeze
    else
      msg = ''.freeze
    end
    body = [
      _div_nav(env),
      _div_desc('Case Information'.freeze, msg),
      _div_case(env, cse),
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_case()


  ###############################################
  # Display an Entry
  #
  def _call_entry(env)
    env['icfs.page'] = 'Entry View'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    enum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Entry requested'.freeze) if enum == 0
    ent = api.entry_read(cid, enum, lnum)
    if lnum != 0
      msg = 'This is a historical version of this Entry'.freeze
    else
      msg = ''.freeze
    end
    body = [
      _div_nav(env),
      _div_desc('View Entry'.freeze, msg),
      _div_entry(env, ent),
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_entry()


  ###############################################
  # Display a Log
  #
  def _call_log(env)
    env['icfs.page'] = 'Log View'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    lnum = _util_num(env, 2)
    raise(Error::Interface, 'No log requested'.freeze) if lnum == 0
    log = api.log_read(cid, lnum)
    body = [
      _div_nav(env),
      _div_desc('View Log'.freeze, ''.freeze),
      _div_log(env, log)
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_log()


  ###############################################
  # Display an Action
  #
  def _call_action(env)
    env['icfs.page'] = 'Action View'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    anum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Action requested'.freeze) if anum == 0

    # get the action
    act = api.action_read(cid, anum, lnum)
    if lnum != 0
      msg = 'This is a historical version of this Action'.freeze
    else
      msg = ''.freeze
    end

    # get the entries
    query = {
      caseid: cid,
      action: anum,
      purpose: 'Action Entries'.freeze,
    }
    resp = api.entry_search(query)

    # display
    body = [
      _div_nav(env),
      _div_desc('View Action'.freeze, msg),
      _div_action(env, act),
      _div_list(env, resp, ListEntry),
      _div_page(resp){|qu, txt| _a_entry_search(env, qu, txt)},
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_action()


  ###############################################
  # Display an Index
  #
  def _call_index(env)
    env['icfs.page'] = 'Index View'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    xnum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Index requested'.freeze) if xnum == 0

    # get the index
    idx = api.index_read(cid, xnum, lnum)
    if lnum != 0
      msg = 'This is a historical version of this Index'.freeze
    else
      msg = ''.freeze
    end

    # get the entries
    query = {
      caseid: cid,
      index: xnum
    }
    resp = api.entry_search(query)

    # display
    body = [
      _div_nav(env) +
      _div_desc('View Index'.freeze, msg),
      _div_index(env, idx),
      _div_list(env, resp, ListEntry),
      _div_page(resp){|qu, txt| _a_entry_search(env, qu, txt)},
    ].join(''.freeze)
    return _resp_success(env, body)
  end # def _call_index()


  ###############################################
  # Get a file
  def _call_file(env)
    env['icfs.page'] = 'File Download'.freeze
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)

    # get filename
    cmps = env['icfs.cmps']
    if cmps.size < 3 || cmps[2].empty?
      raise(Error::Interface, 'No file specified in the URL'.freeze)
    end
    fnam = Rack::Utils.unescape(cmps[2])
    ma = /^(\d+)-(\d+)-(\d+)-(.+)$/.match fnam
    if !ma
      raise(Error::Interface, 'File not properly specified in URL'.freeze)
    end
    enum = ma[1].to_i
    lnum = ma[2].to_i
    fnum = ma[3].to_i
    ext = ma[4].rpartition('.'.freeze)[2]

    # get MIME-type by extension
    if ext.empty?
      mime = 'application/octet-stream'.freeze
    else
      mime = Rack::Mime.mime_type('.' + ext)
    end

    # return the file
    file = api.file_read(cid, enum, lnum, fnum)
    fr = Web::FileResp.new(file)
    headers = {
      'Content-Length' => file.size.to_s,
      'Content-Type' => mime,
      'Content-Disposition' => 'attachment'.freeze,
    }
    return [200, headers, fr]

  end # def _call_file()


###########################################################
# Generate HTML divs
###########################################################

  ###############################################
  # Navbar div
  #
  def _div_nav(env)

    unam = env['icfs'].user
    cid = env['icfs.cid']

    # with case
    if cid
      tc = _a_case(env, cid, 0, cid)
      tabs = [
        _a_entry_search(env, {
            caseid: cid,
            purpose: 'Case Entries'.freeze,
          }, 'Entries'.freeze),
        _a_index_search(env, {
            caseid: cid,
            purpose: 'Case Indexes'.freeze,
          }, 'Indexes'.freeze),
        _a_stats(env, {
            caseid: cid,
            purpose: 'Case Stats'.freeze,
          }, 'Stats'.freeze),
        _a_entry_tags(env, {
            caseid: cid,
            purpose: 'Entry Tags'.freeze,
          }, 'Entry Tags'.freeze),
        _a_index_tags(env, {
            caseid: cid,
            purpose: 'Index Tags'.freeze,
          }, 'Index Tags'.freeze),
        _a_entry_edit(env, cid, 0, 0, 'New Entry'.freeze),
        _a_index_edit(env, cid, 0, 'New Index'.freeze),
      ]

    # no case
    else
      tc = ''.freeze
      tabs = [
        _a_action_search(env, {
            assigned: unam,
            status: true,
            flag: true,
            purpose: 'Flagged Actions'.freeze,
          }, 'Actions'.freeze),
        _a_case_search(env, {
            grantee: unam,
            status: true,
            template: false,
            purpose: 'Open Cases'.freeze,
          }, 'Cases'.freeze),
        _a_stats(env, {
            credit: unam,
            after: Time.now.to_i - 60*60*24*30,
            purpose: 'User Stats - Last 30 days'.freeze,
          }, 'Stats'.freeze),
        _a_info(env, 'Info'.freeze),
      ]
    end

    # tab divs
    tabs = tabs.map{|aa| DivNavTab % aa}.join(''.freeze)

    return DivNav % [
      _a_home(env, 'ICFS'.freeze),
      tc,
      tabs
    ]
  end # def _div_nav()


  # navbar div
  DivNav = '
  <div class="nav">
    <div class="nav-icfs">%s</div>
    <div class="nav-case">%s</div>%s
  </div>'.freeze


  # navbar tab
  DivNavTab = '
    <div class="nav-tab">%s</div>'.freeze


  ###############################################
  # Message div
  #
  def _div_msg(env, msg)
    DivMsg % msg
  end # def _div_msg()


  # message div
  DivMsg = '
  <div class="message">%s
  </div>'.freeze


  ###############################################
  # Info div
  #
  def _div_info(env)
    api = env['icfs']
    tz = env['icfs.tz']

    # roles/groups/perms
    roles = api.roles.map{|rol| DivInfoList % Rack::Utils.escape_html(rol)}
    grps = api.groups.map{|grp| DivInfoList % Rack::Utils.escape_html(grp)}
    perms = api.perms.map{|pm| DivInfoList % Rack::Utils.escape_html(pm)}

    # global stats
    gstats = api.gstats.map{|st| DivInfoList % Rack::Utils.escape_html(st)}

    return DivInfo % [
      Rack::Utils.escape_html(tz),
      Rack::Utils.escape_html(api.user),
      roles.join(''.freeze),
      grps.join(''.freeze),
      perms.join(''.freeze),
      gstats.join(''.freeze),
    ]
  end # def _div_info()


  # info div
  DivInfo = '
  <div class="info">
    <div class="list">
      <div class="list-row">
        <div class="list-label">Timezone:</div>
        <div class="list-text-s">%s</div>
      </div>
      <div class="list-row">
        <div class="list-label">User:</div>
        <div class="list-text-m">%s</div>
      </div>
      <div class="list-row">
        <div class="list-label">Roles:</div>
        <div class="user-list">%s
        </div>
      </div>
      <div class="list-row">
        <div class="list-label">Groups:</div>
        <div class="user-list">%s
        </div>
      </div>
      <div class="list-row">
        <div class="list-label">Perms:</div>
        <div class="user-list">%s
        </div>
      </div>
      <div class="list-row">
        <div class="list-label">Stats:</div>
        <div class="user-list">%s
        </div>
      </div>
    </div>
  </div>'.freeze


  # List items in the info div
  DivInfoList = '
          <div>%s</div>'.freeze


  # Column classes by symbol
  ListColClass = {
    entry: 'list-int'.freeze,
    action: 'list-int'.freeze,
    index: 'list-int'.freeze,
    log: 'list-int'.freeze,
    tags: 'list-int'.freeze,
    tag: 'list-tag'.freeze,
    stats: 'list-int'.freeze,
    time: 'list-time'.freeze,
    title: 'list-title'.freeze,
    caseid: 'list-caseid'.freeze,
    stat: 'list-stat'.freeze,
    sum: 'list-float'.freeze,
    count: 'list-int'.freeze,
    files: 'list-int'.freeze,
    user: 'list-usergrp'.freeze,
  }.freeze


  ###############################################
  # Search results list div
  #
  # @param env [Hash] Rack environment
  # @param resp [Hash] Search response
  # @param list [Array] List of object items to display and how
  #
  def _div_list(env, resp, list)
    return _div_msg(env, 'No results found'.freeze) if resp[:list].size == 0

    # did we query with caseid?
    qcid = resp[:query].key?(:caseid)

    # copy the query
    qu = resp[:query].dup

    # header row
    hcols = list.map do |sym, opt|
      if sym == :caseid && qcid
        ''.freeze
      else
        DivListHeadItems[sym]
      end
    end
    head = DivListHead % hcols.join(''.freeze)

    # search results into rows
    rows = resp[:list].map do |sr|
      obj = sr[:object]
      cid = obj[:caseid]

      cols = list.map do |sym, opt|
        it = obj[sym]
        cc = ListColClass[sym]

        # snippets are special non-column, not in the object itself
        if sym == :snippet
          if sr[:snippet]
            next( DivListItem % ['list-snip'.freeze, sr[:snippet]])
          else
            next(''.freeze)
          end

        # redacted result
        elsif it.nil?
          next( DivListItem % [cc, '&mdash;'.freeze])
        end

        # normal result
        case sym

        # snippets - a special non-column, not in the object itself
        when :snippet
          if sr[:snippet]
            cd = sr[:snippet]
          else
            cd = nil
          end

        # entry
        when :entry
          case opt
          when :current
            cd = _a_entry(env, cid, it, 0, it.to_s)
          when :log
            cd = _a_entry(env, cid, it, obj[:log], it.to_s)
          else
            cd = it.to_s
          end

        # action
        when :action
          case opt
          when :current
            cd = (it == 0) ? ''.freeze :  _a_action(env, cid, it, 0, it.to_s)
          when :log
            if it != 0
              cd = _a_action(env, cid, it, obj[:log], it.to_s)
            else
              cd = ''.freeze
            end
          else
            cd = it == 0 ? ''.freeze : it.to_s
          end

        # index
        when :index
          case opt
          when :entry
            cd = (it == 0) ? ''.freeze : it.to_s
          when :current
            cd = _a_index(env, cid, it, 0, it.to_s)
          when :log
            if it != 0
              cd = _a_index(env, cid, it, obj[:log], it.to_s)
            else
              cd = ''.freeze
            end
          else
            cd = it.to_s
          end

        # log
      when :log
          case opt
          when :link
            cd = _a_log(env, cid, it, it.to_s)
          else
            cd = it.to_s
          end

        # tags
        when :tags
          if it.size == 1 && it[0] == ICFS::TagNone
            cd = ''.freeze
          else
            cd = it.size.to_s
          end

        # tag - the result of a tags aggregation
        when :tag
          qu[:tags] = it

          case opt
          when :entry
            qu[:purpose] = 'Entry Tag Search'.freeze
            cd = _a_entry_search(env, qu, it)
          when :index
            qu[:purpose] = 'Index Tag Search'.freeze
            cd = _a_index_search(env, qu, it)
          when :case
            qu[:purpose] = 'Case Tag Search'.freeze
            cd = _a_case_search(env, qu, it)
          when :action
            qu[:purpose] = 'Action Tag Search'.freeze
            cd = _a_action_search(env, qu, it)
          end

        # time
        when :time
          case opt
          when :entry
            cd = _a_entry(env, cid, obj[:entry], 0, _util_time(env, it))
          when :log
            cd = _a_log(env, cid, obj[:log], _util_time(env, it))
          else
            cd = _util_time(env, it)
          end

        # title
        when :title
          case opt
          when :entry
            cd = _a_entry(env, cid, obj[:entry], 0, it)
          when :action
            cd = _a_action(env, cid, obj[:action], 0, it)
          when :case
            cd = _a_case(env, cid, 0, it)
          when :index
            cd = _a_index(env, cid, obj[:index], 0, it)
          when :action
            cd = _a_action(env, cid, obj[:action], 0, it)
          else
            cd = Rack::Utils.escape_html(it)
          end

        # caseid
        when :caseid
          case opt
          when :current
            cd = _a_case(env, it, 0, it)
          when :mixed
            cd = qcid ? nil : _a_case(env, it, 0, it)
          else
            cd = Rack::Utils.escape_html(cid)
          end

        # stat - only on stats aggregation
        when :stat
          qu[:stat] = it
          qu[:purpose] = 'Entry Stat Search'.freeze
          cd = _a_entry_search(env, qu, it)

        # sum - only on stats aggregation
        when :sum
          cd = it.to_s

        # count - only on stats aggregation
        when :count
          cd = it.to_s

        # files
        when :files
          cd = it == 0 ? ''.freeze : it.to_s

        # user
        when :user
          cd = Rack::Utils.escape_html(it)

        # stats
        when :stats
          cd = it == 0 ? ''.freeze : it.to_s

        # huh?
        else
          raise NotImplementedError, sym.to_s
        end

        cd ? (DivListItem % [cc, cd]) : ''.freeze
      end

      DivListRow % cols.join(''.freeze)
    end

    return DivList % [head, rows.join(''.freeze)]

  end # def _div_list()


  # Search results list
  DivList = '
  <div class="list">%s%s
  </div>'.freeze

  # Search results row
  DivListRow = '
    <div class="list-row">%s
    </div>'.freeze

  # Search results header
  DivListHead = '
    <div class="list-head">%s
    </div>'.freeze

  # Search results header items
  DivListHeadItems = {
    tags: '
      <div class="list-int">Tags</div>'.freeze,
    tag: '
      <div class="list-tag">Tag</div>'.freeze,
    entry: '
      <div class="list-int">Entry</div>'.freeze,
    index: '
      <div class="list-int">Index</div>'.freeze,
    action: '
      <div class="list-int">Action</div>'.freeze,
    log: '
      <div class="list-int">Log</div>'.freeze,
    title: '
      <div class="list-title">Title</div>'.freeze,
    caseid: '
      <div class="list-caseid">Case ID</div>'.freeze,
    stats: '
      <div class="list-int">Stats</div>'.freeze,
    time: '
      <div class="list-time">Date/Time</div>'.freeze,
    stat: '
      <div class="list-stat">Stat Name</div>'.freeze,
    sum: '
      <div class="list-float">Total</div>'.freeze,
    count: '
      <div class="list-int">Count</div>'.freeze,
    files: '
      <div class="list-int">Files</div>'.freeze,
    user: '
      <div class="list-usergrp">User</div>'.freeze,
    snippet: ''.freeze
  }.freeze

  # search results item
  DivListItem = '
      <div class="%s">%s</div>'.freeze


  ###############################################
  # Page description div
  #
  def _div_desc(head, body)
    DivDesc % [ head, body ]
  end # def _div_desc()

  # Div description
  DivDesc = '
  <div class="desc">
    <div class="desc-head">%s</div>
    %s
  </div>'.freeze


  ###############################################
  # Page navigation div
  #
  # @param resp [Array<Hash>] search results
  # @param pr [Proc] A Proc which is called instead of yield
  # @yield [query, disp] the query to run and what to display
  # @yieldparam query [Hash] the query to execute
  # @yieldparam disp [String] what to display in the link
  # @yieldreturn [String] the HTML link for the query page
  # @return [String] a HTML div for page nav
  #
  def _div_page(resp, pr=nil)

    hits = resp[:hits]
    page_size = resp[:size]
    tot_pages = ((hits - 1) / page_size) + 1
    disp_pages = (tot_pages > 10) ? 10 : tot_pages

    query = resp[:query].dup
    if query.key?(:page)
      cur = query[:page].to_i
    else
      cur = 1
    end
    if cur > disp_pages
      cur = disp_pages
    end

    # numeric links
    ary = []
    disp_pages.times do |pg|
      page = pg + 1
      if page == cur
        ary << '<b>%d</b>'.freeze % page
      else
        query[:page] = page
        if pr
          val = pr.call(query, page.to_s)
        else
          val = yield(query, page.to_s)
        end
        ary << val
      end
    end

    # previous
    if cur == 1
      prev_page = ''.freeze
    else
      query[:page] = cur - 1
      if pr
        prev_page = pr.call(query, '(Prev)'.freeze)
      else
        prev_page = yield(query, '(Prev)'.freeze)
      end
    end

    # next
    if cur == disp_pages
      next_page = ''.freeze
    else
      query[:page] = cur + 1
      if pr
        next_page = pr.call(query, '(Next)'.freeze)
      else
        next_page = yield(query, '(Next)'.freeze)
      end
    end

    return DivPage % [
      prev_page, ary.join(' '.freeze), next_page,
      hits, tot_pages
    ]
  end # def _div_page()


  # Pageing div
  DivPage = '
  <div class="pagenav">
    &lt;&lt; %s %s %s &gt;&gt;<br>
    Hits: %d Pages: %d
  </div>'.freeze


  ###############################################
  # Home div
  #
  def _div_home(env)
    api = env['icfs']

    # get the user & roles
    ur = [ api.user ]
    ur.concat api.roles
    now = Time.now.to_i

    # actions
    useract = ur.map do |ug|
      cl = [
        _a_case_search(env, {
            grantee: ug,
            status: true,
            template: false,
            purpose: 'Open Cases'.freeze
          }, 'open'.freeze),
        _a_case_search(env, {
            grantee: ug,
            status: false,
            template: false,
            purpose: 'Closed Cases'.freeze
          }, 'closed'.freeze),
        _a_case_search(env, {
              grantee: ug,
              perm: ICFS::PermAction,
              status: true,
              template: false,
              purpose: 'Action Manager Cases'.freeze
            }, 'action mgr'.freeze),
        _a_case_tags(env, {
            grantee: ug,
            status: true,
            template: false,
            purpose: 'Open Case Tags'.freeze
          }, 'tags'.freeze),
      ].map{|lk| DivHomeLink % lk }.join(''.freeze)

      al = [
        _a_action_search(env, {
            assigned: ug,
            status: true,
            flag: true,
            purpose: 'Flagged Actions'.freeze
          }, 'flagged'.freeze),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            before: now,
            sort: 'time_asc'.freeze,
            purpose: 'Actions - Past Date'.freeze,
          }, 'past'.freeze),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            after: now,
            sort: 'time_desc'.freeze,
            purpose: 'Actions - Future Date'.freeze,
          }, 'future'.freeze),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            purpose: 'Open Actions'.freeze
          }, 'all open'.freeze),
        _a_action_tags(env, {
            assigned: ug,
            status: true,
            purpose: 'Open Action Tags'.freeze
          }, 'tags'.freeze),
      ].map{|lk| DivHomeLink % lk }.join(''.freeze)

      ol = [
        _a_case_search(env, {
          grantee: ug,
          perm: ICFS::PermManage,
          status: true,
          template: false,
          purpose: 'Managed Cases'.freeze,
          }, 'managed'.freeze),
        _a_case_search(env, {
            grantee: ug,
            perm: ICFS::PermManage,
            status: true,
            template: true,
            purpose: 'Templates'.freeze,
          }, 'templates'.freeze),
        _a_stats(env, {
            credit: ug,
            after: Time.now.to_i - 60*60*24*30,
            purpose: 'User/Role Stats - 30 days'.freeze,
          }, '30-day stats'.freeze),
      ].map{|lk| DivHomeLink % lk }.join(''.freeze)


      DivHomeUr % [Rack::Utils.escape_html(ug), al, cl, ol ]
    end

    DivHome % useract.join(''.freeze)
  end # def _div_home()


  # Home div
  DivHome = '
  <div class="home list">
    <div class="list-head">
      <div class="list-usergrp">User/Role</div>
      <div class="list-text-s">Actions</div>
      <div class="list-text-s">Cases</div>
      <div class="list-text-s">Other</div>
    </div>%s
  </div>'.freeze


  # Home user/role
  DivHomeUr = '
    <div class="list-row">
      <div class="list-usergrp">%s</div>
      <div class="links-list">%s
      </div>
      <div class="links-list">%s
      </div>
      <div class="links-list">%s
      </div>
    </div>'.freeze


  # Home Link
  DivHomeLink = '
        <div class="list-text-s">%s</div>'.freeze


  ###############################################
  # Case Create Form
  #
  def _form_create(env)
    [ FormCaseCreate, ''.freeze ]
  end # def _form_create()


  # Form to create a new case
  FormCaseCreate = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Create Case</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Describe the new case to be created.
        </div></div>
        <div class="sect-fill"> </div>
      </div>
      <div class="form-row">
        <div class="list-label">Case ID:</div>
        <input class="form-caseid" name="create_cid" type="text">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A unique identifier for the case. This is fixed at case creation and
          cannot be changed.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Template:</div>
        <input class="form-check" name="create_tmpl" type="checkbox"
          value="true">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Select to make this a template which will provide default values
          when making new cases.
        </div></div>
      </div>
    </div>'.freeze


  ###############################################
  # Form div
  #
  # @param env [Hash] Rack environment
  # @param path [String] the path to submit
  # @param cid [String, NilClass] case ID
  # @param parts [Array<String>] the form sections
  # @param button [String] the submit button text
  def _div_form(env, path, cid, parts, button)
    spath = env['SCRIPT_NAME'] + path
    spath += Rack::Utils.escape(cid) if cid
    return DivForm % [
      spath,
      parts.join(''.freeze),
      button,
    ]
  end # def _div_form()

  # Form
  DivForm = '
  <div class="form"><form method="post" action="%s"
      enctype="multipart/form-data" accept-charset="utf-8">
%s
    <input class="submit" type="submit" value="%s">
  </form></div>'.freeze



  ###############################################
  # Case div
  #
  def _div_case(env, cse)
    api = env['icfs']
    urg = api.urg
    cid = cse['caseid']
    al = api.access_list(cid)

    status = cse['status'] ? 'Open'.freeze : 'Closed'.freeze
    template = cse['template'] ? 'Yes'.freeze : 'No'.freeze

    # case links
    links = [
      _a_log_search(env, {caseid: cid}, 'History of Case'.freeze),
    ]
    if al.include?(ICFS::PermManage)
      links << _a_case_edit(env, cid, 'Edit This Case'.freeze)
      if cse['template']
        links << _a_case_create(env, cid, 'Create New Case'.freeze)
      end
    end
    links.map!{|aa| DivCaseLink % aa}

    # action section
    if al.include?(ICFS::PermAction)
      now = Time.now.to_i
      actions = [
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            flag: true,
            purpose: 'Flagged Actions'.freeze,
          }, 'flagged'.freeze),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            before: now,
            sort: 'time_asc'.freeze,
            purpose: 'Actions - Past Date'.freeze,
          }, 'past'.freeze),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            after: now,
            sort: 'time_desc'.freeze,
            purpose: 'Actions - Future Date'.freeze,
          }, 'future'.freeze),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            purpose: 'Open Actions'.freeze,
          }, 'all open'.freeze),
        _a_action_tags(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            purpose: 'Open Action Tags'.freeze,
          }, 'tags'.freeze),
      ].map{|lk| DivCaseLink % lk}
      actions = DivCaseActions % actions.join(''.freeze)
    else
      actions = ''.freeze
    end

    # tags
    tags = cse['tags'].map do |tg|
      DivCaseTag % _a_case_search(env, {tags: tg},
        Rack::Utils.escape_html(tg) )
    end

    # access control
    acc = cse['access'].map do |ac|
      pm = Rack::Utils.escape_html(ac['perm'])
      ugl = ac['grant'].map do |ug|
        DivCaseGrant % Rack::Utils.escape_html(ug)
      end
      DivCaseAccess % [ pm, ugl.join(''.freeze) ]
    end

    # stats
    if cse['stats']
      stats = cse['stats'].map do |st|
        DivCaseStatEach % _a_entry_search(env, { caseid: cid, stat: st,
          purpose: 'Entries with Stat'.freeze },
          Rack::Utils.escape_html(st) )
      end
      stats = DivCaseStats % stats.join(''.freeze)
    else
      stats = ''.freeze
    end

    return DivCase % [
      Rack::Utils.escape_html(cid),
      _a_log(env, cid, cse['log'], cse['log'].to_s),
      status,
      template,
      links.join(''.freeze),
      Rack::Utils.escape_html(cse['title']),
      acc.join(''.freeze),
      tags.join(''.freeze),
      stats,
      actions,
    ]
  end # def _div_case()

  # Case div
  DivCase = '
  <div class="sbar">
    <div class="sbar-side">
      <div class="sbar-side-head">Case</div>
      <div class="list">
        <div class="list-row">
          <div class="list-label">Case ID:</div>
          <div class="list-caseid">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Log:</div>
          <div class="list-int">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Status:</div>
          <div class="list-text-s">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Template:</div>
          <div class="list-text-s">%s</div>
        </div>
      </div>
      <div class="sect">%s
      </div>
    </div>
    <div class="sbar-main">
      <div class="sbar-main-head">%s</div>
      <div class="sect">
        <div class="sect-head">Access Control</div>
        <div class="list">
          <div class="list-head">
            <div class="list-perm">Permission</div>
            <div class="list-usergrp">Users/Groups</div>
          </div>%s
        </div>
      </div>
      <div class="sect">
        <div class="sect-head">Tags</div>%s
      </div>%s%s
    </div>
  </div>'.freeze


  # Case div action links
  DivCaseActions = '
      <div class="sect">
        <div class="sect-head">Actions</div>%s
      </div>'.freeze


  # Case div links
  DivCaseLink = '
        <div>%s</div>'.freeze

  # Case div each access
  DivCaseAccess = '
          <div class="list-row">
            <div class="list-perm">%s</div>
            <div class="list-vert list-usergrp">%s
            </div>
          </div>'.freeze


  # Case div each grant
  DivCaseGrant = '
            <div>%s</div>'.freeze


  # Case div each tag
  DivCaseTag = '
        <div class="item-tag">%s</div>'.freeze


  # Case div stats section
  DivCaseStats = '
      <div class="sect">
        <div class="sect-head">Stats</div>
        <div class="list">%s
        </div>
      </div>'.freeze


  # Case div each stat
  DivCaseStatEach = '
          <div class="list-perm">%s</div>'.freeze


  ###############################################
  # Entry div
  #
  def _div_entry(env, ent)
    api = env['icfs']
    cid = ent['caseid']

    links = []

    enum = ent['entry']
    links << _a_entry_edit(env, cid, enum, 0, 'Edit This Entry'.freeze)

    lnum = ent['log']
    links << _a_log_search(env, {
          'caseid' => cid,
          'entry' => enum,
          'purpose' => 'History of Entry'.freeze,
        }, 'History of Entry'.freeze)

    if ent['action']
      anum = ent['action']
      action = DivEntryAction % _a_action(env, cid, anum, 0, anum.to_s)
      links << _a_entry_edit(env, cid, 0, anum, 'New Entry in Action'.freeze)
    else
      action = ''.freeze
    end

    if ent['index']
      indexes = ent['index'].map do |xnum|
        idx = api.index_read(cid, xnum)
        DivEntryIndexEach % _a_index(env, cid, xnum, 0, idx['title'])
      end
      index = DivEntryIndex % indexes.join(''.freeze)
    else
      index = ''.freeze
    end

    tags = ent['tags'].map do |tag|
      DivEntryTag % _a_entry_search(env, {
          'caseid' => cid,
          'tags' => tag,
          'purpose' => 'Tag Entries'.freeze,
        }, tag)
    end

    if ent['perms']
      pa = ent['perms'].map do |pm|
        DivEntryPermEach % Rack::Utils.escape_html(pm)
      end
      perms = DivEntryPerms % pa.join("\n".freeze)
    else
      perms = ''.freeze
    end

    if ent['stats']
      sa = ent['stats'].map do |st|
        ca = st['credit'].map do |ug|
          Rack::Utils.escape_html(ug)
        end
        DivEntryStatEach % [
          Rack::Utils.escape_html(st['name']),
          st['value'],
          ca.join(', '.freeze)
        ]
      end
      stats = DivEntryStats % sa.join("\n".freeze)
    else
      stats = ''.freeze
    end

    if ent['files']
      fa = ent['files'].map do |fd|
        DivEntryFileEach % _a_file(env, cid, enum, fd['log'],
          fd['num'], fd['name'], fd['name'])
      end
      files = DivEntryFiles % fa.join("\n".freeze)
    else
      files = ''.freeze
    end

    return DivEntry % [
      _a_case(env, cid, 0, cid),
      _a_entry(env, cid, enum, 0, enum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      Rack::Utils.escape_html(ent['user']),
      action,
      links.map{|lk| DivEntryLink % lk }.join(''.freeze),
      Rack::Utils.escape_html(ent['title']),
      _util_time(env, ent['time']),
      Rack::Utils.escape_html(ent['content']),
      tags.join("\n".freeze),
      index,
      perms,
      stats,
      files
    ]
  end # def _div_entry()

  # entry div
  DivEntry = '
  <div class="sbar">
    <div class="sbar-side">
      <div class="sbar-side-head">Entry</div>
      <div class="list">
        <div class="list-row">
          <div class="list-label">Case:</div>
          <div class="list-caseid">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Entry:</div>
          <div class="list-int">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Log:</div>
          <div class="list-int">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">User:</div>
          <div class="list-text-m">%s</div>
        </div>%s
        <div class="sect">%s
        </div>
      </div>
    </div>
    <div class="sbar-main">
      <div class="sbar-main-head">%s
        <div class="sbar-main-sub">%s</div>
      </div>
      <pre class="sbar-main-content">%s</pre>
      <div class="sect">
        <div class="sect-head">Tags</div>
        <div class="tags-list">%s
        </div>
      </div>%s%s%s%s
    </div>
  </div>'.freeze


  # entry tag each
  DivEntryTag = '
          <div>%s</div>'.freeze


  # entry link each
  DivEntryLink = '
          <div>%s</div>'.freeze


  # entry action
  DivEntryAction = '
      <div class="list-row">
        <div class="list-label">Action:</div>
        <div class="list-int">%s</div>
      </div>'.freeze


  # entry index
  DivEntryIndex = '
      <div class="sect">
        <div class="sect-head">Indexes</div>
        <div class="index-list">%s
        </div>
      </div>'.freeze


  # entry index each
  DivEntryIndexEach = '
          <div>%s</div>'.freeze


  # entry perms
  DivEntryPerms = '
      <div class="sect">
        <div class="sect-head">Permissions</div>
        <div class="perms-list">%s
        </div>
      </div>'.freeze


  # entry perm each
  DivEntryPermEach = '
          <div>%s</div>'.freeze


  # entry stats
  DivEntryStats = '
      <div class="sect">
        <div class="sect-head">Stats</div>
        <div class="stats-list">%s
        </div>
      </div>'.freeze


  # entry each stat
  DivEntryStatEach = '
          <div>%s %f %s</div>'.freeze


  # entry files
  DivEntryFiles = '
      <div class="sect">
        <div class="sect-head">Files</div>
        <div class="files-list">%s
        </div>
      </div>'.freeze


  # entry each file
  DivEntryFileEach = '
          <div>%s</div>'.freeze


  ###############################################
  # Log div
  #
  def _div_log(env, log)
    cid = log['caseid']
    lnum = log['log']
    enum = log['entry']['num']

    navp = (lnum == 1) ? 'prev'.freeze : _a_log(env, cid, lnum-1, 'prev'.freeze)
    navn = _a_log(env, cid, lnum + 1, 'next'.freeze)

    time = _util_time(env, log['time'])

    if log['case_hash']
      chash = DivLogCase % _a_case(env, cid, lnum, log['case_hash'])
    else
      chash = ''.freeze
    end

    if log['action']
      action = DivLogAction % [
        _a_action(env, cid, log['action']['num'], lnum, log['action']['hash']),
        log['action']['num'],
      ]
    else
      action = ''.freeze
    end

    if log['index']
      index = DivLogIndex % [
        _a_index(env, cid, log['index']['num'], lnum, log['index']['hash']),
        log['index']['num'],
      ]
    else
      index = ''.freeze
    end

    if log['files_hash']
      ha = log['files_hash']
      fa = []
      ha.each_index do |ix|
        fa << DivLogFileEach % [
            _a_file(env, cid, enum, lnum, ix, 'file.bin'.freeze, ha[ix]),
            ix
        ]
      end
      files = DivLogFiles % fa.join("\n".freeze)
    else
      files = ''.freeze
    end

    return DivLog % [
      Rack::Utils.escape_html(cid),
      log['log'],
      navp,
      navn,
      _util_time(env, log['time']),
      Rack::Utils.escape_html(log['user']),
      log['prev'],
      _a_entry(env, cid, enum, lnum, log['entry']['hash']),
      enum,
      chash,
      action,
      index,
      files
    ]
  end # def _div_log()

  # log div
  DivLog = '
  <div class="sbar">
    <div class="sbar-side">
      <div class="sbar-side-head">Log</div>
      <div class="list">
        <div class="list-row">
          <div class="list-label">Case:</div>
          <div class="list-caseid">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Log:</div>
          <div class="list-int">%d</div>
        </div>
      </div>
      <div class="nav_links">
        <div class="prev">%s</div>
        <div class="next">%s</div>
      </div>
    </div>
    <div class="sbar-main list">
      <div class="list-row">
        <div class="list-label">Time:</div>
        <div class="list-time">%s</div>
      </div>
      <div class="list-row">
        <div class="list-label">User:</div>
        <div class="list-usergrp">%s</div>
      </div>
      <div class="list-row">
        <div class="list-label">Prev:</div>
        <div class="list-hash">%s</div>
      </div>
      <div class="list-row">
        <div class="list-label">Entry:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>%s%s%s%s
    </div>
  </div>'.freeze


  # log action
  DivLogAction = '
      <div class="list-row">
        <div class="list-label">Action:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>'.freeze


  # log index
  DivLogIndex = '
      <div class="list-row">
        <div class="list-label">Index:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>'.freeze


  # log case
  DivLogCase = '
      <div class="list-row">
        <div class="list-label">Case:</div>
        <div class="list-hash">%s</div>
      </div>
  '.freeze

  # log file
  DivLogFiles = '
      <div class="list-row">
        <div class="list-label">Files:</div>
        <div class="files-list">%s
        </div>
      </div>'.freeze


  # log file
  DivLogFileEach = '
          <div>
            <div class="list-hash">%s</div>
            <div class="list-int">%d</div>
          </div>'.freeze


  ###############################################
  # Action div
  #
  def _div_action(env, act)
    api = env['icfs']
    cid = act['caseid']

    # get perms & user/roles
    al = api.access_list(act['caseid'])
    perm_act = al.include?(ICFS::PermAction)
    ur = Set.new
    ur.add api.user
    ur.merge api.roles

    links = []
    anum = act['action']
    links << _a_entry_edit(env, cid, 0, anum, 'New Entry in Action'.freeze)

    lnum = act['log']
    links << _a_log_search(env, {
        'caseid' => cid,
        'action' => anum,
        'purpose' => 'Action History'.freeze,
      }, 'History of Action'.freeze)

    # each task
    tasks = []
    ta = act['tasks']
    ta.each_index do |ixr|
      ix = ixr + 1
      tk = ta[ixr]

      # if we can edit
      edit = (ixr == 0) ? perm_act : ur.include?(tk['assigned'])

      # tags
      tags = tk['tags'].map do |tg|
        qu = {
          assigned: tk['assigned'],
          tags: tg,
        }
        qu[:caseid] = cid if tk['assigned'] == ICFS::UserCase
        DivActionTag % _a_action_search(env, qu, tg)
      end

      tasks << DivActionTask % [
        edit ? 'task-ed'.freeze : 'task-ro'.freeze,
        Rack::Utils.escape_html(tk['assigned']),
        Rack::Utils.escape_html(tk['title']),
        tk['status'] ? 'Open'.freeze : 'Closed'.freeze,
        tk['flag'] ? 'Raised'.freeze : 'Normal'.freeze,
        _util_time(env, tk['time']),
        tags.join(''.freeze),
      ]
    end

    return DivAction % [
      _a_case(env, cid, 0, cid),
      _a_action(env, cid, anum, 0, anum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      links.map{|lk| DivActionLink % lk }.join(''.freeze),
      tasks.join(''.freeze)
    ]
  end # def _div_action()


  # Action div
  DivAction = '
  <div class="sbar">

    <div class="sbar-side">
      <div class="sbar-side-head">Action</div>
      <div class="list">
        <div class="list-row">
          <div class="list-label">Case:</div>
          <div class="list-caseid">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Action:</div>
          <div class="list-int">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Log:</div>
          <div class="list-int">%s</div>
        </div>
        <div class="sect">%s
        </div>
      </div>
    </div>

    <div class="sbar-main">%s
    </div>

  </div>'.freeze


  # Action link
  DivActionLink = '
          <div>%s</div>'.freeze


  # Action task
  DivActionTask = '
      <div class="list task">
        <div class="list-row %s">
          <div class="list-label">Tasked:</div>
          <div class="list-usergrp">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Title:</div>
          <div class="list-title">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Open:</div>
          <div class="list-text-s">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Flag:</div>
          <div class="list-text-s">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Time:</div>
          <div class="list-time">%s</div>
        </div>
        <div class="list-row">
          <div class="list-label">Tags:</div>
          <div class="list-vert">%s
          </div>
        </div>
      </div>'.freeze


  # Action Tag
  DivActionTag = '
            <div>%s</div>'.freeze


  ###############################################
  # Index div
  #
  def _div_index(env, idx)
    cid = idx['caseid']

    links = []
    xnum = idx['index']
    links << _a_index_edit(env, cid, xnum, 'Edit This Index'.freeze)

    lnum = idx['log']
    links << _a_log_search(env, {
          'caseid' => cid,
          'index' => xnum,
          'purpose' => 'Index History'.freeze,
        }, 'History of Index')

    tags = idx['tags'].map do |tg|
      DivIndexTag % _a_index_search(env, {
          'caseid' => cid,
          'tags' => tg,
          'purpose' => 'Index Entries'.freeze,
        }, tg)
    end

    return DivIndex % [
      _a_case(env, cid, 0, cid),
      _a_index(env, cid, xnum, 0, xnum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      links.map{|lk| DivIndexLink % lk }.join(''.freeze),
      Rack::Utils.escape_html(idx['title']),
      Rack::Utils.escape_html(idx['content']),
      tags.join(''.freeze),
    ]
  end # def _div_index()


  # Index div
  DivIndex = '
    <div class="sbar">
      <div class="sbar-side">
        <div class="sbar-side-head">Index</div>
        <div class="list">
          <div class="list-row">
            <div class="list-label">Case:</div>
            <div class="list-caseid">%s</div>
          </div>
          <div class="list-row">
            <div class="list-label">Index:</div>
            <div class="list-int">%s</div>
          </div>
          <div class="list-row">
            <div class="list-label">Log:</div>
            <div class="list-int">%s</div>
          </div>
        </div>
        <div class="sect">%s
        </div>
      </div>
      <div class="sbar-main">
        <div class="sbar-main-head">%s</div>
        <pre class="sbar-main-content">%s</pre>
        <div class="sect">
          <div class="sect-head">Tags</div>
          <div class="tags-list">%s
          </div>
        </div>
      </div>
    </div>'.freeze


  # Index Links
  DivIndexLink = '
          <div>%s</div>'.freeze

  # Index tags
  DivIndexTag = '
            <div>%s</div>'.freeze


  ###############################################
  # Description div for queries
  #
  def _div_query(env, type, sup, query, disp=false)

    # query purpose
    if query[:purpose]
      purp = Rack::Utils.escape_html(query[:purpose])
    else
      purp = type
    end

    # display the query parameters
    list = []
    sup.each do |txt, sym, pr|
      next if !query.key?(sym) || (sym == :purpose) || (sym == :page)
      val = query[sym]

      case pr
      when :string
        para = Rack::Utils.escape_html(val)
      when :boolean
        para = val ? 'true'.freeze : 'false'.freeze
      when :integer
        para = val.to_s
      when :time
        para = _util_time(env, val)
      else
        raise NotImplementedError, pr.to_s
      end

      list << '<i>%s:</i> %s'.freeze % [sym, para]
    end
    if list.empty?
      paras = ''.freeze
    else
      paras = ' &ndash; ' + list.join(', '.freeze)
    end

    # enable value
    value = disp ? 'true'.freeze : 'false'.freeze

    return _div_desc(purp, DivQuery % [ type, paras, value ])
  end # def _div_query()


  # Query div
  DivQuery = '<span class="desc-query"
        onclick="enaDiv(&quot;que-form&quot;, &quot;que-ena&quot;)"
        >%s</span>
    <div class="tip"><div class="tip-disp"></div><div class="tip-info">
    What kind of search was performed.  Query terms are displayed with name
    of the term in italics followed by the search value.
    Click to display search form.
    </div></div>
    %s
    <input name="que-enable" id="que-ena" type="hidden" value="%s">'.freeze


###########################################################
# Generate forms
###########################################################


  ###############################################
  # Query form
  #
  def _form_query(env, sup, query, act, disp=false)

    # supported params
    inputs = sup.map do |txt, sym, pr|

      case sym
      when :caseid
        ilabel = 'Case ID'.freeze
        iclass = 'form-caseid'.freeze
        ihint = 'Filter for a specific case.'.freeze
      when :title
        ilabel = 'Title'.freeze
        iclass = 'form-title'.freeze
        ihint = 'Text search within the title.'.freeze
      when :prefix
        ilabel = 'Prefix'.freeze
        iclass = 'form-title'.freeze
        ihint = 'Filter for titles starting with fixed text.'.freeze
      when :content
        ilabel = 'Content'.freeze
        iclass = 'form-content'.freeze
        ihint = 'Text search within the content.'.freeze
      when :tags
        ilabel = 'Tag'.freeze
        iclass = 'form-tag'.freeze
        ihint = 'Filter for only a specific tag.'.freeze
      when :action
        ilabel = 'Action'.freeze
        iclass = 'form-int'.freeze
        ihint = 'Filter for a specific action (by number).'.freeze
      when :before
        ilabel = 'Before'.freeze
        iclass = 'form-time'.freeze
        ihint = 'Filter for items occuring before this date and time.'.freeze
      when :after
        ilabel = 'After'.freeze
        iclass = 'form-time'.freeze
        ihint = 'Filter for items occuring after this date and time.'.freeze
      when :credit
        ilabel = 'Credit'.freeze
        iclass = 'form-usergrp'.freeze
        ihint = 'Filter for stats crediting this user or role.'.freeze
      when :size
        ilabel = 'Size'.freeze
        iclass = 'form-int'.freeze
        ihint = 'Number of results to be returned per page.'.freeze
      when :page
        next
      when :sort
        ilabel = 'Sort'.freeze
        iclass = 'form-sort'.freeze
        ihint = 'How to sort the results.'.freeze
      when :purpose
        next
      when :user
        ilabel = 'User'.freeze
        iclass = 'form-usergrp'.freeze
        ihint = 'Filter for logs authored by this user.'.freeze
      when :grantee
        ilabel = 'Grantee'.freeze
        iclass = 'form-usergrp'.freeze
        ihint = 'Filter for cases granting this user or role a permission.'.freeze
      when :perm
        ilabel = 'Permission'.freeze
        iclass = 'form-perm'.freeze
        ihint = 'Filter for cases granting this permission.'.freeze
      when :entry
        ilabel = 'Entry'.freeze
        iclass = 'form-int'.freeze
        ihint = 'Filter for logs recording specified entry (by number).'.freeze
      when :index
        ilabel = 'Index'.freeze
        iclass = 'form-int'.freeze
        ihint = 'Filter for specified index (by number).'.freeze
      when :assigned
        ilabel = 'Assigned'.freeze
        iclass = 'form-usergrp'.freeze
        ihint = 'Filter for tasks assigned to specified user or role.'.freeze
      when :status
        ilabel = 'Status'.freeze
        iclass = 'form-boolean'.freeze
        ihint = 'Filter for open items. Use true or false.'.freeze
      when :flag
        ilabel = 'Flag'.freeze
        iclass = 'form-boolean'.freeze
        ihint = 'Filter for flagged tasks. Use true or false.'.freeze
      when :template
        ilabel = 'Template'.freeze
        iclass = 'form-boolean'.freeze
        ihint = 'Filter for template cases. Use true or false.'.freeze
      when :stat
        ilabel = 'Stat'.freeze
        iclass = 'form-boolean'.freeze
        ihint = 'Filter for stats by name. Use true or false.'.freeze
      else
        raise NotImplementedError, sym.to_s
      end

      case pr
      when :string
        itype = 'text'.freeze
        ivalue = query[sym] || ''.freeze
      when :boolean
        itype = 'text'.freeze
        if query[sym].nil?
          ivalue = ''.freeze
        else
          ivalue = query[sym] ? 'true'.freeze : 'false'.freeze
        end
      when :integer
        itype = 'text'.freeze
        ivalue = query[sym] ? query[sym].to_s : ''
      when :time
        itype = 'text'.freeze
        ivalue = query[sym] ? _util_time(env, query[sym]) :  ''.freeze
      else
        raise NotImplementedError, pr.to_s
      end

      FormQueryItem % [ilabel, txt, iclass, itype, ivalue, ihint]
    end

    # display the form
    formClass = disp ? ''.freeze : ' hidden'.freeze

    return FormQuery % [
      formClass,
      act,
      inputs.join(''.freeze)
    ]
  end # def _form_query


  # Query Form
  FormQuery = '
  <div class="form%s" id="que-form"><form method="get" action="%s">%s
    <input class="submit" type="submit" value="Search">
  </form></div>'.freeze


  # Query form item
  FormQueryItem = '
    <div class="form-row">
      <div class="list-label">%s:</div>
      <input name="%s" class="%s" type="%s" value="%s">
      <div class="tip"><div class="tip-disp"></div><div class="tip-info">
        %s
      </div></div>
    </div>'.freeze


  ###############################################
  # Case form
  def _form_case(env, cse)

    status = ' checked'.freeze if cse['status']

    # tags
    tags_cnt = 0
    if cse['tags'][0] != ICFS::TagNone
      tags_list = cse['tags'].map do |tg|
        tags_cnt = tags_cnt + 1
        FormCaseTag % [ tags_cnt, Rack::Utils.escape_html(tg) ]
      end
      tags = tags_list.join(''.freeze)
    else
      tags = ''.freeze
    end

    # stats
    stats_cnt = 0
    if cse['stats']
      stats_list = cse['stats'].map do |st|
        stats_cnt += 1
        FormCaseStat % [stats_cnt, Rack::Utils.escape_html(st)]
      end
      stats = stats_list.join(''.freeze)
    else
      stats = ''.freeze
    end

    # access
    acc_cnt = 0
    acc_list = cse['access'].map do |ad|
      acc_cnt = acc_cnt + 1

      grant_cnt = 0
      grants = ad['grant'].map do |ug|
        grant_cnt = grant_cnt + 1
        FormCaseGrant % [ acc_cnt, grant_cnt,
          Rack::Utils.escape_html(ug)
        ]
      end

      FormCaseAccess % [
        acc_cnt, grant_cnt,
        acc_cnt, Rack::Utils.escape_html(ad['perm']),
        grants.join(''.freeze),
      ]
    end

    return FormCase % [
        Rack::Utils.escape_html(cse['title']),
        status,
        tags_cnt, tags,
        acc_cnt, acc_list.join(''.freeze),
        stats_cnt, stats,
      ]
  end # def _form_case()

  # Case form
  FormCase = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Case</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          The current state of a case.
        </div></div>
        <div class="sect-fill"> </div>
      </div>
      <div class="form-row">
        <div class="list-label">Title:</div>
        <input class="form-title" name="cse-title" type="text" spellcheck="true"
          value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          One line description of the case.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Open:</div>
        <input class="form-check" name="cse-status" type="checkbox"
          value="true"%s>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Select to indicate the case is currently open.
        </div></div>
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Tags</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A way to group related cases together.
        </div></div>
        <div class="sect-fill"> </div>
        <button class="tag-add" type="button"
          onClick="addTag(&quot;cse-tag-list&quot;)">+</button>
      </div>
      <div class="tags-list" id="cse-tag-list">
        <input type="hidden" name="cse-tag" value="%d">%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Access</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Grant permissions to a set of users, roles, or groups. This is
          controls access for this specific case.
        </div></div>
        <div class="sect-fill"> </div>
        <button class="access-add" type="button" onClick="cseAddAcc()">+
        </button>
      </div>
      <input type="hidden" id="cse-acc-cnt" name="cse-acc-cnt" value="%d">
      <div class="access list" id="cse-acc-list">
        <div class="list-head">
          <div class="list-perm">Permission</div>
          <div class="list-usergrp">Grants to</div>
        </div>%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Stats</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          List of case-specific things which can be assigned numerical
          values.  This is combined with the global stats list to get the
          list of allowed stats.
        </div></div>
        <div class="sect-fill"> </div>
        <button class="stats-add" type="button" onclick="cseAddStat()">+
        </button>
      </div>
      <div class="stat-list" id="cse-stat-list">
        <input type="hidden" name="cse-stat" value="%d">%s
      </div>
    </div>'.freeze


  # Case form Tag each
  FormCaseTag = '
        <div>
          <input class="form-tag" type="text" name="cse-tag-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'.freeze


  # Case form Stat each
  FormCaseStat = '
        <div>
          <input class="form-stat" type="text" name="cse-stat-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'.freeze


  # Case form Access each
  FormCaseAccess = '
          <div class="list-row">
            <input type="hidden" name="cse-acc-%d" value="%d">
            <input class="form-perm" type="text" name="cse-acc-%d-perm"
              value="%s">
            <div class="grant-list">%s
            </div>
            <button class="add-grant" type="button"
              onclick="cseAddGrant(this)">+
            </button>
          </div>'.freeze

  # Case form Grant each
  FormCaseGrant = '
              <div>
                <input class="form-usergrp" type="text" name="cse-acc-%d-%d"
                  value="%s">
              </div>'.freeze


  #############################################
  # New entry form
  #
  def _form_entry(env, cid, ent=nil)
    api = env['icfs']

    # title
    if ent && ent['title']
      title = Rack::Utils.escape_html(ent['title'])
    else
      title = ''.freeze
    end

    # time
    if ent && ent['time']
      time = _util_time(env, ent['time'])
    else
      time = ''.freeze
    end

    # content
    if ent && ent['content']
      content = Rack::Utils.escape_html(ent['content'])
    else
      content = ''.freeze
    end

    # files
    files_cnt = 0
    files_list = []
    if ent && ent['files']
      ent['files'].each do |fd|
        files_cnt = files_cnt + 1
        files_list << FormEntryFileEach % [
          files_cnt, Rack::Utils.escape_html(fd['name']),
          files_cnt,
          files_cnt, fd['num'], fd['log']
        ]
      end
      files = files_list.join("\n".freeze)
    else
      files = ''.freeze
    end

    # tags
    tags_cnt = 0
    if ent && ent['tags'][0] != ICFS::TagNone
      tags_list = ent['tags'].map do |tg|
        tags_cnt = tags_cnt + 1
        FormEntryTagEach % [tags_cnt, Rack::Utils.escape_html(tg)]
      end
      tags = tags_list.join(''.freeze)
    else
      tags = ''.freeze
    end

    # indexes
    index_cnt = 0
    if ent && ent['index']
      idx_list = ent['index'].map do |xnum|
        index_cnt += 1
        idx = api.index_read(cid, xnum, 0)
        FormEntryIndexEach % [
          index_cnt, xnum,
          Rack::Utils.escape_html(idx['title'])
        ]
      end
      index = idx_list.join(''.freeze)
    else
      index = ''.freeze
    end

    # stats select
    stats_sel = api.stats_list(cid).to_a.sort.map do |stat|
      esc = Rack::Utils.escape_html(stat)
      FormEntryStatOpt % [esc, esc]
    end
    stats_sel = FormEntryStatSel % stats_sel.join(''.freeze)

    # stats count & list
    stats_cnt = 0
    stats_list = []
    if ent && ent['stats']
      stats_list = ent['stats'].map do |st|
        stats_cnt = stats_cnt + 1

        claim_cnt = 0
        claims = st['credit'].map do |ug|
          claim_cnt = claim_cnt + 1
          FormEntryClaim % [stats_cnt, claim_cnt,
            Rack::Utils.escape_html(ug)]
        end

        esc = Rack::Utils.escape_html(st['name'])
        FormEntryStatEach % [
          stats_cnt, claim_cnt,
          stats_cnt, esc, esc,
          stats_cnt, st['value'].to_s,
          claims.join(''.freeze)
        ]
      end
      stats = stats_list.join(''.freeze)
    else
      stats = ''.freeze
    end

    # perms select
    al = env['icfs'].access_list(cid)
    perms_sel = al.sort.map do |pm|
      esc = Rack::Utils.escape_html(pm)
      FormEntryPermOpt % [esc, esc]
    end
    perms_sel = perms_sel.join(''.freeze)

    # perms count & list
    perms_cnt = 0
    if ent && ent['perms']
      perms_list = ent['perms'].map do |pm|
        perms_cnt = perms_cnt + 1
        esc = Rack::Utils.escape_html(pm)
        FormEntryPermEach % [esc, perms_cnt, esc]
      end
      perms = perms_list.join(''.freeze)
    else
      perms = ''.freeze
    end

    return FormEntry % [
        ent ? ent['entry'] : 0,
        (ent && ent['action']) ? ent['action'] : 0,
        title, time, content,
        tags_cnt, tags,
        files_cnt, files,
        env['SCRIPT_NAME'],
        Rack::Utils.escape(cid),
        index_cnt, index,
        stats_sel, stats_cnt, stats,
        perms_sel, perms_cnt, perms
      ]
  end # def _form_entry


  # entry edit form
  FormEntry = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Entry</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Describe the activity.
        </div></div>
        <div class="sect-fill"> </div>
        <input name="ent-num" type="hidden" value="%d">
        <input name="ent-act" type="hidden" value="%d">
      </div>
      <div class="form-row">
        <div class="list-label">Title:</div>
        <input class="form-title" name="ent-title" type="text"
          spellcheck="true" value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          One line description of the entry.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Time:</div>
        <input class="form-time" name="ent-time" type="text" value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          When the entry occured.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Content:</div>
        <textarea class="form-content" name="ent-content">%s</textarea>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A complete description of the entry.
        </div></div>
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Tags</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A way to group related entries together.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">
          <button class="tag-add" type="button"
            onClick="addTag(&quot;ent-tag-list&quot;)">+</button>
        </div>
      </div>
      <div class="tags-list" id="ent-tag-list">
        <input type="hidden" name="ent-tag" value="%d">%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Files</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Attach files to this entry.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">
          <button class="file-add" type="button" onClick="entAddFile()">+
          </button>
        </div>
      </div>
      <input type="hidden" id="ent-file-cnt" name="ent-file-cnt" value="%d">
      <div class="files-list" id="ent-file-list">%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Indexes</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Real-world factors that appear in a case multiple times.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">
          <input class="form-index" type="text" id="ent-idx-lu"
            name="ent-idx-lu">
          <button class="index-add" type="button"
            onclick="entAddIndex()">?</button>
        </div>
      </div>
      <input type="hidden" id="ent-idx-script" value="%s">
      <input type="hidden" id="ent-idx-caseid" value="%s">
      <input type="hidden" id="ent-idx-cnt" name="ent-idx-cnt" value="%d">
      <div class="index-list" id="ent-idx-list">%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Stats</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Numerical measurements of things that have occured, associated with
          this entry.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">%s
          <button class="stat-add" type="button" onClick="entAddStat()">+
          </button>
        </div>
      </div>
      <input type="hidden" name="ent-stats-cnt" id="ent-stats-cnt" value="%d">
      <div class="stats-list" id="ent-stats-list">%s
      </div>
    </div>

    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Permissions</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Permissions needed to access this entry.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">
          <select class="perm-sel" id="ent-perm-sel" name="ent-perm-sel">%s
          </select>
          <button class="perm-add" type="button" onClick="entAddPerm()">+
          </button>
        </div>
      </div>
      <input type="hidden" name="ent-perm-cnt" id="ent-perm-cnt" value="%d">
      <div class="perms-list" id="ent-perm-list">%s
      </div>
    </div>'.freeze


  # Entry form tag each
  FormEntryTagEach = '
        <div>
          <input class="form-tag" type="text" name="ent-tag-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'.freeze


  # Entry form index each
  FormEntryIndexEach = '
        <div>
          <input type="hidden" name="ent-idx-%d" value="%d">%s
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'.freeze


  # Entry form Perm each
  FormEntryPermEach = '
        <div>%s
          <input type="hidden" name="ent-perm-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'.freeze


  # Entry form Perm option
  FormEntryPermOpt = '
        <option value="%s">%s</option>'.freeze


  # Entry form file each
  FormEntryFileEach = '
    <div>
      <input class="form-file-name" type="text" name="ent-file-%d-name"
        value="%s">
      <input class="form-file-upl" type="file" name="ent-file-%d-file">
      <input type="hidden" name="ent-file-%d-num" value="%d-%d">
      <button class="form-del" type="button" onclick="delDiv(this)">X
      </button>
    </div>'.freeze


  # Entry form Stat option
  FormEntryStatOpt = '
            <option value="%s">%s</option>'.freeze


  # Entry form Stat select
  FormEntryStatSel = '
          <select class="stat-sel" id="ent-stat-sel" name="ent-stat-sel">%s
          </select>'.freeze


  # Entry form Stat each
  FormEntryStatEach = '
        <div class="list-row">
          <input type="hidden" name="ent-stat-%d" value="%d">
          <input type="hidden" name="ent-stat-%d-name" value="%s">
          <div class="list-stat">%s</div>
          <input class="form-float" type="text" name="ent-stat-%d-value"
            value="%s">
          <div class="list-vert">%s
          </div>
          <button class="add-claim" type="button"
            onClick="entAddClaim(this)">+
          </button>
        </div>'.freeze


  # Entry form Stat Claim
  FormEntryClaim = '
            <div>
              <input class="form-usergrp" type="text" name="ent-stat-%d-%d"
                value="%s">
            </div>'.freeze


  ###############################################
  # Action form
  #
  def _form_action(env, cid, act = nil, opt={})
    api = env['icfs']

    # new action
    if !act
      ta = [{
        'assigned' => ICFS::UserCase,
        'title' => ''.freeze,
        'status' => true,
        'flag' => true,
        'time' => nil,
        'tags' => [ ICFS::TagNone ],
      }]
    else
      ta = act['tasks']
    end

    # get perms
    al = api.access_list(cid)
    perm_act = al.include?(ICFS::PermAction)
    if !perm_act && !act
      raise(Error::Perms, 'Missing perm: %s'.freeze % ICFS::PermAction)
    end

    # get user/group list
    ur = Set.new
    ur.add api.user
    ur.merge api.roles

    # editing
    if opt[:edit]
      ena_val = 'true'.freeze
      ena_class_add = ''.freeze
      ena_class_tasks = ''.freeze
    else
      ena_val = 'false'.freeze
      ena_class_add = ' invisible'.freeze
      ena_class_tasks = ' hidden'.freeze
    end

    # each task
    tasks = []
    ta.each_index do |ixr|
      ix = ixr + 1
      tk = ta[ixr]

      # figure out if we can edit
      if ixr == 0
        edit = perm_act
      else
        edit = ur.include?(tk['assigned'])
      end

      # never edit the tasked
      esc = Rack::Utils.escape_html(tk['assigned'])
      ug = FormActionTaskedRo % [ ix, esc, esc ]

      # can edit it
      if edit
        title = FormActionTitleEd % [
          ix, Rack::Utils.escape_html(tk['title']) ]
        status = FormActionStatusEd % [
          ix, tk['status'] ? ' checked'.freeze : ''.freeze ]
        flag = FormActionFlagEd % [
          ix, tk['flag'] ? ' checked'.freeze : ''.freeze ]
        if tk['time']
          time = FormActionTimeEd % [ ix, _util_time(env, tk['time']) ]
        else
          time = FormActionTimeEd % [ix, ''.freeze]
        end

        if tk['tags'][0] == ICFS::TagNone
          tags_cnt = 1
          tags = FormActionTagEd % [ix, 1, ''.freeze]
        else
          tags_cnt = 0
          tags = tk['tags'].map do |tg|
            tags_cnt = tags_cnt + 1
            FormActionTagEd % [
              ix, tags_cnt, Rack::Utils.escape_html(tg) ]
          end
          tags = tags.join(''.freeze)
        end

        tag_list = 'act-%d-tag-list' % ix
        tag_add = FormActionTagButton % tag_list

      # can't edit
      else
        esc = Rack::Utils.escape_html(tk['title'])
        title = FormActionTitleRo % [ ix, esc, esc ]
        status = FormActionStatusRo % [ ix,
          tk['status'] ? 'true'.freeze : 'false'.freeze,
          tk['status'] ? 'Open'.freeze : 'Closed'.freeze,
        ]
        if tk['flag']
          flag = FormActionFlagRo % ix
        else
          flag = FormActionFlagEd % [ ix, ''.freeze ]
        end
        esc = _util_time(env, tk['time'])
        time = FormActionTimeRo % [ ix, esc, esc ]

        tags_cnt = 0
        if tk['tags'][0] != ICFS::TagNone
          tags = tk['tags'].map do |tg|
            tags_cnt = tags_cnt + 1
            esc = Rack::Utils.escape_html(tg)
            FormActionTagRo % [ ix, tags_cnt, esc, esc ]
          end
          tags = tags.join(''.freeze)
        else
          tags = ''.freeze
        end

        tag_add = ''.freeze

      end

      tasks << FormActionTask % [
        edit ? 'ed'.freeze : 'ro'.freeze,
        ug, title, status, flag, time, ix, ix, tags_cnt, tags, tag_add
      ]
    end

    return FormAction % [
        act ? act['action'] : 0,
        ena_class_add,
        ena_val,
        tasks.size,
        act ? act['action'] : 0,
        ena_class_tasks,
        tasks.join(''.freeze)
      ]
  end # def _form_action()


  # action edit form
  FormAction = '
    <div class="sect" id="act_section">
      <div class="sect-main">
        <div class="sect-label">Action</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A unit of work, accomplished in a set of related real-world
          and administrative activitires.
        </div></div>
        <div class="sect-fill"> </div>
        <input name="act-num" type="hidden" value="%d">
        <div class="sect-right">
          <button id="act-ena-button" class="act-ena" type="button"
            onclick="actEnable()">Toggle Edit
          </button>
        </div>
        <div id="act-task-add" class="sect-right%s">
          <button class="tsk-add" type="button" onclick="actAddTask()">+
          </button>
        </div>
        <input id="act-ena" name="act-ena" type="hidden" value="%s">
        <input id="act-cnt" name="act-cnt" type="hidden" value="%d">
        <input type="hidden" name="act-num" value="%d">
      </div>
      <div id="act-tasks" class="%s">%s
      </div>
    </div>'.freeze


  # action task
  FormActionTask = '
        <div class="task %s">
          <div class="form-row">
            <div class="list-label">Tasked:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              A user or role tasked with working on the action.
            </div></div>%s
          </div>
          <div class="form-row">
            <div class="list-label">Title:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              One line summary of the action from the point of view of the
              tasked user or role.
            </div></div>%s
          </div>
          <div class="form-row">
            <div class="list-label">Open:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              Action open for the tasked user or role.
            </div></div>%s
          </div>
          <div class="form-row">
            <div class="list-label">Flag:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              Flag the action for attention by the user or role.
            </div></div>%s
          </div>
          <div class="form-row">
            <div class="list-label">Time:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              Time associated with the action for the user or role.  This can
              be a due date, an assigned date, or any other useful date or
              time.
            </div></div>%s
          </div>
          <div class="form-row">
            <div class="list-label">Tags:</div>
            <div class="tip"><div class="tip-disp"></div><div class="tip-info">
              A way to group of actions together.
            </div></div>
            <div class="tags-list" id="act-%d-tag-list">
              <input type="hidden" name="act-%d-tag" value="%d">%s
            </div>%s
          </div>
        </div>'.freeze


  # action tasked editable
  FormActionTaskedEd = '
            <input class="form-usergrp" name="act-%d-task" type="text"
              value="%s">'.freeze


  # action tasked read only
  FormActionTaskedRo = '
            <input name="act-%d-task" type="hidden" value="%s">
            <div class="list-usergrp">%s</div>'.freeze


  # action title editable
  FormActionTitleEd = '
            <input class="form-title" name="act-%d-title" type="text"
              value="%s">'.freeze


  # action title read only
  FormActionTitleRo = '
            <input name="act-%d-title" type="hidden" value="%s">
            <div class="list-title">%s</div>'.freeze


  # action open editable
  FormActionStatusEd = '
            <input class="form-check" name="act-%d-status" type="checkbox"
              value="true"%s>'.freeze

  # action open readonly
  FormActionStatusRo = '
            <input name="act-%d-status" type="hidden" value="%s">
            <div class="item-boolean">%s</div>'.freeze


  # action flag editable
  FormActionFlagEd = '
            <input class="form-check" name="act-%d-flag" type="checkbox"
              value="true"%s>'.freeze


  # action flag read-only
  FormActionFlagRo = '
            <input name="act-%d-flag" type="hidden" value="true">
            <div class="item-boolean">flagged</div>'.freeze


  # action time editable
  FormActionTimeEd = '
            <input class="form-time" name="act-%d-time" type="text"
              value="%s">'.freeze


  # action time read-only
  FormActionTimeRo = '
            <input name="act-%d-time" type="hidden" value="%s">
            <div class="item-time">%s</div>'.freeze


  # action tag editable
  FormActionTagEd = '
              <div>
                <input class="form-tag" type="text" name="act-%d-tag-%d"
                  value="%s"><button class="form-del" type="button"
                  onclick="delDiv(this)">X</button>
              </div>'.freeze


  # action tag read-only
  FormActionTagRo = '
              <div>
                <input type="hidden" name="act-%d-tag-%d" value="%s">%s
              </div>'.freeze


  # action tag button
  FormActionTagButton = '
            <button class="tag-add" type="button"
              onClick="addTag(&quot;%s&quot;)">+</button>'.freeze


  ###############################################
  # Index form
  def _form_index(env, cid, idx=nil)

    # title
    if idx && idx['title']
      title = Rack::Utils.escape_html(idx['title'])
    else
      title = ''.freeze
    end

    # content
    if idx && idx['content']
      content = Rack::Utils.escape_html(idx['content'])
    else
      content = ''.freeze
    end

    # tags
    tags_cnt = 0
    if idx && idx['tags'][0] != ICFS::TagNone
      tags_list = idx['tags'].map do |tg|
        tags_cnt += 1
        FormIndexTagEach % [tags_cnt, Rack::Utils.escape_html(tg)]
      end
      tags = tags_list.join(''.freeze)
    else
      tags = ''.freeze
    end

    return FormIndex % [
        idx ? idx['index'] : 0,
        title, content,
        tags_cnt, tags
      ]

  end # def _form_index()


  # Index form
  FormIndex = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Index</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A real-world factor that may appear in a case multiple times.
        </div></div>
        <div class="sect-fill"> </div>
        <input name="idx-num" type="hidden" value="%d">
      </div>
      <div class="form-row">
        <div class="list-label">Title:</div>
        <input class="form-title" name="idx-title" type="text"
          spellcheck="true" value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          One line description of the index.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Content:</div>
        <textarea class="form-content" name="idx-content">%s</textarea>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A complete description of the index.
        </div></div>
      </div>
    </div>
    <div class="sect">
      <div class="sect-head">
        <div class="sect-label">Tags</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A way to group related indexes together.
        </div></div>
        <div class="sect-fill"> </div>
        <div class="sect-right">
          <button class="tag-add" type="button"
            onClick="addTag(&quot;idx-tag-list&quot;)">+</button>
        </div>
      </div>
      <div class="tag-list" id="idx-tag-list">
        <input type="hidden" name="idx-tag" value="%d">%s
      </div>
    </div> '.freeze


  # Index form tag
  FormIndexTagEach = '
          <div>
            <input class="form-tag" type="text" name="idx-tag-%d" value="%s">
          </div>'.freeze


###########################################################
# Post
###########################################################


  ###############################################
  # Case edit
  #
  def _post_case(env, para)

    # case object
    cse = {}

    # title
    cse['title'] = para['cse-title']

    # status
    cse['status'] = (para['cse-status'] == 'true'.freeze) ? true : false

    # tags
    tags = []
    tcnt = para['cse-tag'].to_i
    if tcnt > 100
      raise(Error::Interface, 'Tag count too large'.freeze)
    end
    tcnt.times do |ix|
      tx = 'cse-tag-%d'.freeze % [ix + 1]
      tag = para[tx]
      next if !tag || tag.empty?
      tags << tag
    end
    if tags.empty?
      cse['tags'] = [ ICFS::TagNone ]
    else
      cse['tags'] = tags.uniq.sort
    end

    # access
    acc = []
    acnt = para['cse-acc-cnt'].to_i
    if acnt > 100
      raise(Error::Interface, 'Access count too large'.freeze)
    end
    acnt.times do |ix|
      ixr = ix + 1

      pnam = para['cse-acc-%d-perm'.freeze % ixr]
      gcnt = para['cse-acc-%d'.freeze % ixr].to_i
      next if gcnt == 0 || !pnam || pnam.empty?

      grant = []
      if gcnt > 100
        raise(Error::Interface, 'Grant count too large'.freeze)
      end
      gcnt.times do |gx|
        sug = para['cse-acc-%d-%d'.freeze % [ixr, gx+1]]
        next if !sug || sug.empty?
        grant << sug
      end

      next if grant.empty?
      acc << {
        'perm' => pnam,
        'grant' => grant
      }
    end
    cse['access'] = acc

    # stats
    stats = []
    scnt = para['cse-stat'].to_i
    if scnt > 100
      raise(Error::Interface, 'Stat count too large')
    end
    scnt.times do |ix|
      sx = 'cse-stat-%d' % [ix + 1]
      stat = para[sx]
      next if !stat || stat.empty?
      stats << stat
    end
    cse['stats'] = stats unless stats.empty?

    return cse
  end # def _post_case()


  ###############################################
  # Entry edit
  #
  def _post_entry(env, para)
    api = env['icfs']

    # entry object
    ent = {}

    # entry
    enum = para['ent-num'].to_i
    ent['entry'] = enum if enum != 0

    # action
    anum = para['ent-act'].to_i
    ent['action'] = anum if anum != 0

    # time
    tstr = para['ent-time']
    time = _util_time_parse(env, tstr)
    ent['time'] = time if time

    # title & content
    ent['title'] = para['ent-title']
    ent['content'] = para['ent-content']

    # tags
    tags = []
    tcnt = para['ent-tag'].to_i
    raise(Error::Interface, 'too many tags'.freeze) if(tcnt > 100)
    tcnt.times do |ix|
      tx = 'ent-tag-%d'.freeze % [ix + 1]
      tag = para[tx]
      tags << tag unless( !tag || tag.empty? )
    end
    ent['tags'] = tags.uniq.sort unless tags.empty?

    # indexes
    index = []
    icnt = para['ent-idx-cnt'].to_i
    raise(Error::Interface, 'Too many indexes'.freeze) if(icnt > 100)
    icnt.times do |ix|
      tx = 'ent-idx-%d'.freeze % (ix + 1)
      xnum = para[tx].to_i
      index << xnum unless xnum == 0
    end
    ent['index'] = index.uniq.sort unless index.empty?

    # perms
    perms = []
    pcnt = para['ent-perm-cnt'].to_i
    raise(Error::Interface, 'Too many perms'.freeze) if(pcnt > 100)
    pcnt.times do |ix|
      px = 'ent-perm-%d'.freeze % [ix + 1]
      pm = para[px]
      next if !pm || pm.empty?
      perms << pm
    end
    ent['perms'] = perms unless perms.empty?

    # stats
    stats = []
    scnt = para['ent-stats-cnt'].to_i
    raise(Error::Interface, 'Too many stats'.freeze) if(scnt > 100)
    scnt.times do |ix|
      ixr = ix + 1
      sname = para['ent-stat-%d-name'.freeze % ixr]
      sval = para['ent-stat-%d-value'.freeze % ixr]
      next if !sname || !sval || sname.empty? || sval.empty?

      sval = sval.to_f

      scred = para['ent-stat-%d'.freeze % ixr].to_i
      sugs = []
      raise(Error::Interface, 'Too many credits'.freeze) if(scred > 100)
      scred.times do |cx|
        sug = para['ent-stat-%d-%d'.freeze % [ixr, cx + 1]]
        next if !sug || sug.empty?
        sugs << sug
      end

      next if sugs.empty?
      stats << {
        'name' => sname,
        'value' => sval,
        'credit' => sugs
      }
    end
    ent['stats'] = stats unless stats.empty?

    # files
    files = []
    fcnt = para['ent-file-cnt'].to_i
    raise(Error::Interface, 'Too many files'.freeze) if(fcnt > 100)
    fcnt.times do |ix|
      ixr = ix + 1
      fnam = para['ent-file-%d-name' % ixr]
      fupl = para['ent-file-%d-file' % ixr]
      fnum = para['ent-file-%d-num' % ixr]

      if fnum
        fnum, flog = fnum.split('-'.freeze).map do |xx|
          y = xx.to_i
          (y == 0) ? nil : y
        end
      else
        fnum = nil
        flog = nil
      end

      if fupl && !fupl.empty?
        ftmp = api.tempfile
        IO::copy_stream(fupl[:tempfile], ftmp)
        fnam = fupl[:filename] if fnam.empty?
        fupl[:tempfile].close!
        files << {
          'temp' => ftmp,
          'name' => fnam
        }
      elsif fnam && !fnam.empty? && fnum && flog
        files << {
          'num' => fnum,
          'log' => flog,
          'name' => fnam
        }
      end
    end
    ent['files'] = files unless files.empty?

    return ent
  end # def _post_entry()


  ###############################################
  # Action edit
  #
  def _post_action(env, para)

    # action object
    act = {}

    # action
    anum = para['act-num'].to_i
    act['action'] = anum if anum != 0

    # any edit?
    return anum unless para['act-ena'] == 'true'.freeze

    # tasks
    tasks = []
    acnt = para['act-cnt'].to_i
    raise(Error::Interface, 'Too many tasks'.freeze) if(acnt > 100)
    acnt.times do |ix|
      tx = 'act-%d'.freeze % [ix + 1]

      ug = para[tx + '-task'.freeze]
      title = para[tx + '-title'.freeze]
      status = (para[tx + '-status'] == 'true'.freeze) ? true : false
      flag = (para[tx + '-flag'] == 'true'.freeze) ? true : false

      tstr = para[tx + '-time']
      time = _util_time_parse(env, tstr)

      tags = []
      tcnt = para[tx + '-tag'.freeze].to_i
      raise(Error::Interface, 'Too many tags'.freeze) if (tcnt > 100)
      tcnt.times do |gx|
        tag = para[tx + '-tag-%d'.freeze % [gx + 1]]
        next if !tag || tag.empty?
        tags << tag
      end
      if tags.empty?
        tags = [ ICFS::TagNone ]
      else
        tags = tags.uniq.sort
      end

      tk = {
        'assigned' => ug,
        'title' => title,
        'time' => time,
        'status' => status,
        'flag' => flag,
        'tags' => tags
      }
      tasks << tk
    end
    act['tasks'] = tasks

    return act
  end # def _post_action()


  ###############################################
  # Index edit
  #
  def _post_index(env, para)

    # index object
    idx = {}

    # number
    xnum = para['idx-num'].to_i
    idx['index'] = xnum if xnum != 0

    # title & content
    idx['title'] = para['idx-title']
    idx['content'] = para['idx-content']

    # tags
    tags = []
    tcnt = para['idx-tag'].to_i
    raise(Error::Interface, 'Too many tags'.freeze) if(tcnt > 100)
    tcnt.times do |ix|
      tx = 'idx-tag-%d'.freeze % [ix + 1]
      tag = para[tx]
      tags << tag unless( !tag | tag.empty? )
    end
    idx['tags'] = tags.uniq.sort unless tags.empty?

    return idx
  end # def _post_index()


###########################################################
# Links
###########################################################

  ###############################################
  # Link to info page
  #
  def _a_info(env, txt)
    '<a href="%s/info">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Case search
  def _a_case_search(env, query, txt)
    '<a href="%s/case_search%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Entry search
  #
  def _a_entry_search(env, query, txt)
    '<a href="%s/entry_search%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Log search
  #
  def _a_log_search(env, query, txt)
    '<a href="%s/log_search%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Action search
  #
  def _a_action_search(env, query, txt)
    '<a href="%s/action_search%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Index search
  #
  def _a_index_search(env, query, txt)
    '<a href="%s/index_search%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to stats search
  #
  def _a_stats(env, query, txt)
    '<a href="%s/stats%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to case tags
  def _a_case_tags(env, query, txt)
    '<a href="%s/case_tags%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to entry tags
  #
  def _a_entry_tags(env, query, txt)
    '<a href="%s/entry_tags/%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt),
    ]
  end # def _a_entry_tags()


  ###############################################
  # Link to action tags
  def _a_action_tags(env, query, txt)
    '<a href="%s/action_tags%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end # def _a_action_tags()


  ###############################################
  # Link to action tags
  def _a_index_tags(env, query, txt)
    '<a href="%s/index_tags/%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end # def _a_index_tags()


  ###############################################
  # Link to create a case
  #
  def _a_case_create(env, tid, txt)
    '<a href="%s/case_create/%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(tid),
      Rack::Utils.escape_html(txt),
    ]
  end


  ###############################################
  # Link to Case edit
  #
  def _a_case_edit(env, cid, txt)
    '<a href="%s/case_edit/%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Entry edit
  #
  def _a_entry_edit(env, cid, enum, anum, txt)
    '<a href="%s/entry_edit/%s/%d/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      enum, anum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Index edit
  #
  def _a_index_edit(env, cid, xnum, txt)
    '<a href="%s/index_edit/%s/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      xnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Home
  #
  def _a_home(env, txt)
    '<a href="%s/home">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Case
  #
  def _a_case(env, cid, lnum, txt)
    '<a href="%s/case/%s/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to an entry
  def _a_entry(env, cid, enum, lnum, txt)
    '<a href="%s/entry/%s/%d/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      enum,
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to a Log
  #
  def _a_log(env, cid, lnum, txt)
    '<a href="%s/log/%s/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to an Action
  #
  def _a_action(env, cid, anum, lnum, txt)
    '<a href="%s/action/%s/%d/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      anum,
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to an Index
  #
  def _a_index(env, cid, xnum, lnum, txt)
    '<a href="%s/index/%s/%d/%d">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      xnum,
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to a File
  #
  def _a_file(env, cid, enum, lnum, fnum, fname, txt)
    '<a href="%s/file/%s/%d-%d-%d-%s">%s</a>'.freeze % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      enum, lnum, fnum, Rack::Utils.escape(fname),
      Rack::Utils.escape_html(txt)
    ]
  end


###########################################################
# Helper methods
###########################################################


  ###############################################
  # Require a GET HTTP method
  #
  def _verb_get(env)
    if env['REQUEST_METHOD'] != 'GET'.freeze
      raise(Error::Interface, 'Only GET method allowed'.freeze)
    end
  end # def _verb_get()


  ###############################################
  # Require a GET or POST method
  #
  def _verb_getpost(env)
    if env['REQUEST_METHOD'] != 'GET'.freeze &&
       env['REQUEST_METHOD'] != 'POST'.freeze
      raise(Error::Interface, 'Only GET or POST method allowed'.freeze)
    end
  end # def _verb_getpost()


  ###############################################
  # Process the POST
  #
  def _util_post(env)
    rck = Rack::Request.new(env)
    para = rck.POST
    para.each do |key, val|
      val.force_encoding('utf-8'.freeze) if val.is_a?(String)
    end
    return para
  end # def _util_post()


  ###############################################
  # Get the case
  #
  def _util_case(env)
    cmps = env['icfs.cmps']
    if cmps.size < 2 || cmps[1].empty?
      raise(Error::NotFound, 'No case specified in the URL'.freeze)
    end
    cid = Rack::Utils.unescape(cmps[1])
    Items.validate(cid, 'case'.freeze, Items::FieldCaseid)
    env['icfs.cid'] = cid
    return cid
  end # def _util_case()


  ###############################################
  # Get a number from the URL
  #
  def _util_num(env, loc)
    cmps = env['icfs.cmps']
    (cmps.size < (loc+1) || cmps[loc].empty?) ? 0 : cmps[loc].to_i
  end # def _util_num()


  ###############################################
  # Epoch time as local
  #
  def _util_time(env, time)
    Time.at(time).getlocal(env['icfs.tz']).strftime('%F %T'.freeze)
  end


  ###############################################
  # Parse a provided time string
  #
  def _util_time_parse(env, str)
    return nil if !str || !str.is_a?(String)
    val = str.strip
    now = Time.now.to_i

    # empty string defaults to now
    return now if val.empty?

    # default use parse
    ma = /[+-]\d{2}:\d{2}$/.match str
    tstr = ma ? str : str + env['icfs.tz']
    time = Time.parse(tstr).to_i
  rescue ArgumentError
    return nil
  end


  # Generate query string
  #
  def _util_query(query)
    if query
      qa = query.map do |key, val|
        '%s=%s'.freeze % [Rack::Utils.escape(key), Rack::Utils.escape(val)]
      end
      return '?'.freeze + qa.join('&amp;'.freeze)
    else
      return ''.freeze
    end
  end # def _util_query()


  ###############################################
  # Parse a query string
  #
  def _util_get_query(env, sup)
    rck = Rack::Request.new(env)
    para = rck.GET
    query = {}

    # supported parameters
    sup.each do |txt, sym, proc|
      val = para[txt]
      next if !val || val.empty?
      case proc
      when :string
        query[sym] = val
      when :array
        query[sym] = val.split(','.freeze).map{|aa| aa.strip}
      when :boolean
        if val == 'true'
          query[sym] = true
        elsif val == 'false'
          query[sym] = false
        end
      when :integer
        query[sym] = val.to_i
      when :time
        if /^\s*\d+\s*$/.match(val)
          time = val.to_i
        else
          time = _util_time_parse(env, val)
        end
        query[sym] = time
      else
        raise NotImplementedError
      end
    end

    return query
  end # def _util_get_query()


###########################################################
# Rack HTTP responses
###########################################################

  ###############################################
  # A Rack HTTP response
  #
  # @param env [Hash] Rack environment
  # @param res [Integer] the HTTP result
  # @param body [Sting] the HTML page body
  #
  def _resp(env, res, body)
    html = Page % [
      env['icfs.page'],
      @css,
      @js,
      body
    ]
    head = {
      'Content-Type' => 'text/html; charset=utf-8'.freeze,
      'Content-Length' => html.bytesize.to_s
    }
    return [res, head, [html]]
  end # def _resp()


  # HTML page
  Page = '<!DOCTYPE html>
<html>
<head>
  <title>%s</title>
  <link rel="stylesheet" type="text/css" href="%s">
  <script src="%s"></script>
</head>
<body>%s
</body>
</html>
'.freeze


  ###############################################
  # Success
  def _resp_success(env, body)
    return _resp(env, 200, body)
  end # def _resp_success()


  ###############################################
  # Bad Request
  #
  def _resp_badreq(env, msg)
    body = _div_nav(env) + _div_msg(env, msg)
    return _resp(env, 400, body)
  end # def _resp_badreq()


  ###############################################
  # Conflict
  #
  def _resp_conflict(env, msg)
    body = _div_nav(env) + _div_msg(env, msg)
    return _resp(env, 409, body)
  end # def _resp_conflict()


  ###############################################
  # Not Found
  #
  def _resp_notfound(env, msg)
    body = _div_nav(env) + _div_msg(env, msg)
    return _resp(env, 404, body)
  end # def _resp_notfound()


  ###############################################
  # Forbidden
  #
  def _resp_forbidden(env, msg)
    body = _div_nav(env) + _div_msg(env, msg)
    return _resp(env, 403, body)
  end # def _resp_forbidden()


end # module ICFS::Web::Client


##########################################################################
# A file response object to use in Rack
#
class FileResp

  ###############################################
  # New response
  #
  def initialize(file)
    @file = file
  end


  # Chunk size of 64 kB
  #
  ChunkSize = 1024 * 64


  ###############################################
  # Provide body of the file in chunks
  #
  def each
    while str = @file.read(ChunkSize)
      yield str
    end
  end


  ###############################################
  # Close the file
  #
  def close
    if @file.respond_to?(:close!)
      @file.close!
    else
      @file.close
    end
  end

end # class ICFS::Web::FileResp

end # module ICFS::Web

end # module ICFS
