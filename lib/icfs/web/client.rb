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

require 'rack'

module ICFS

##########################################################################
# Web interface using Rack
#
module Web

##########################################################################
# Web Client
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
      cmps = path.split('/', -1)
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
        'Case Search',
        'Case Search',
        QueryCase,
        ListCase,
        :case_search,
        Proc.new{|qu, txt| _a_case_search(env, qu, txt) }
      )

    when 'entry_search'
      return _call_search(env,
        'Entry Search',
        'Entry Search',
        QueryEntry,
        ListEntry,
        :entry_search,
        Proc.new{|qu, txt| _a_entry_search(env, qu, txt) }
      )

    when 'log_search'
      return _call_search(env,
        'Log Search',
        'Log Search',
        QueryLog,
        ListLog,
        :log_search,
        Proc.new{|qu, txt| _a_log_search(env, qu, txt) }
      )

    when 'action_search'
      return _call_search(env,
        'Action Search',
        'Action Search',
        QueryAction,
        ListAction,
        :action_search,
        Proc.new{|qu, txt| _a_action_search(env, qu, txt) }
      )

    when 'index_search'
      return _call_search(env,
        'Index Search',
        'Index Search',
        QueryIndex,
        ListIndex,
        :index_search,
        Proc.new{|qu, txt| _a_index_search(env, qu, txt) }
      )

    when 'index_lookup'; return _call_index_lookup(env)

    # aggregations
    when 'stats'
      return _call_search(env,
        'Stats Search',
        'Stats Search',
        QueryStats,
        ListStats,
        :stats,
        nil
      )

    when 'case_tags'
      return _call_search(env,
        'Case Tags',
        'Case Tags Search',
        QueryCaseTags,
        ListCaseTags,
        :case_tags,
        nil
      )

    when 'entry_tags'
      return _call_search(env,
        'Entry Tags',
        'Entry Tag Search',
        QueryEntryTags,
        ListEntryTags,
        :entry_tags,
        nil
      )

    when 'action_tags'
      return _call_search(env,
        'Action Tags',
        'Action Tag Search',
        QueryActionTags,
        ListActionTags,
        :action_tags,
        nil
      )

    when 'index_tags'
      return _call_search(env,
        'Index Tags',
        'Index Tag Search',
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
    when 'action_edit'; return _call_action_edit(env)
    when 'config_edit'; return _call_config_edit(env)

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
      env['icfs.page'] = 'Invalid'
      raise(Error::NotFound, 'Invalid request')
    end

  rescue Error::NotFound => e
    return _resp_notfound( env, 'Not found: %s' %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Perms => e
    return _resp_forbidden( env, 'Forbidden: %s' %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Conflict => e
    return _resp_conflict( env, 'Conflict: %s' %
      Rack::Utils.escape_html(e.message) )

  rescue Error::Value => e
    return _resp_badreq( env, 'Invalid values: %s' %
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
    env['icfs.page'] = 'Info'
    api = env['icfs']
    _verb_get(env)
    body = [
      _div_nav(env),
      _div_desc('Info', ''),
      _div_info(env)
    ].join('')
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
    act = '%s/%s' % [env['SCRIPT_NAME'], env['icfs.cmps'][0]]

    # form
    if env['QUERY_STRING'].empty?
      body = [
        _div_nav(env),
        _div_desc(type, ''),
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

    return _resp_success(env, body.join(''))
  end # def _call_search()


  ###############################################

  # Case query options
  QueryCase = [
    ['title', :title, :string].freeze,
    ['tags', :tags, :string].freeze,
    ['status', :status, :boolean].freeze,
    ['template', :template, :boolean].freeze,
    ['grantee', :grantee, :string].freeze,
    ['perm', :perm, :string].freeze,
    ['size', :size, :integer].freeze,
    ['page', :page, :integer].freeze,
    ['purpose', :purpose, :string].freeze,
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
    ['title', :title, :string].freeze,
    ['content', :content, :string].freeze,
    ['tags', :tags, :string].freeze,
    ['caseid', :caseid, :string].freeze,
    ['action', :action, :integer].freeze,
    ['index', :index, :integer].freeze,
    ['after', :after, :time].freeze,
    ['before', :before, :time].freeze,
    ['stat', :stat, :string].freeze,
    ['credit', :credit, :string].freeze,
    ['size', :size, :integer].freeze,
    ['page', :page, :integer].freeze,
    ['sort', :sort, :string].freeze,
    ['purpose', :purpose, :string].freeze,
  ].freeze


  # Entry query display
  ListEntry = [
    [:caseid, :mixed].freeze,
    [:entry, :current].freeze,
    [:action, :current].freeze,
    [:time, :entry].freeze,
    [:tags, nil].freeze,
    [:indexes, nil].freeze,
    [:files, nil].freeze,
    [:stats, nil].freeze,
    [:title, :entry].freeze,
    [:snippet, nil].freeze,
  ].freeze


  # Log query options
  QueryLog = [
    ['caseid', :caseid, :string].freeze,
    ['after', :after, :time].freeze,
    ['before', :before, :time].freeze,
    ['user', :user, :string].freeze,
    ['case_edit', :case_edit, :boolean].freeze,
    ['entry', :entry, :integer].freeze,
    ['index', :index, :integer].freeze,
    ['action', :action, :integer].freeze,
    ['size', :size, :integer].freeze,
    ['page', :page, :integer].freeze,
    ['sort', :sort, :string].freeze,
    ['purpose', :purpose, :string].freeze,
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
    [:case, :log].freeze,
  ].freeze


  # Task query options
  QueryAction = [
    ['assigned', :assigned, :string].freeze,
    ['caseid', :caseid, :string].freeze,
    ['title', :title, :string].freeze,
    ['status', :status, :boolean].freeze,
    ['flag', :flag, :boolean].freeze,
    ['before', :before, :time].freeze,
    ['after', :after, :time].freeze,
    ['tags', :tags, :string].freeze,
    ['purpose', :purpose, :string].freeze,
    ['size', :size, :integer].freeze,
    ['page', :page, :integer].freeze,
    ['sort', :sort, :string].freeze,
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
    env['icfs.page'] = 'Index Lookup'
    api = env['icfs']
    _verb_get(env)

    # query required
    if env['QUERY_STRING'].empty?
      raise(Error::Interface, 'Query string required')
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
      'Content-Type' => 'application/json',
      'Content-Length' => body.bytesize.to_s
    }
    return [200, head, [body]]
  end # def _call_index_lookup()


  # Index query options
  QueryIndex = [
    ['caseid', :caseid, :string].freeze,
    ['title', :title, :string].freeze,
    ['prefix', :prefix, :string].freeze,
    ['content', :content, :string].freeze,
    ['tags', :tags, :string].freeze,
    ['purpose', :purpose, :string].freeze,
    ['size', :size, :integer].freeze,
    ['page', :page, :integer].freeze,
    ['sort', :sort, :string].freeze,
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
    ['credit', :credit, :string].freeze,
    ['caseid', :caseid, :string].freeze,
    ['before', :before, :time].freeze,
    ['after', :after, :time].freeze,
    ['purpose', :purpose, :string].freeze,
  ].freeze

  # Stats list options
  ListStats = [
    [:stat, nil].freeze,
    [:count, nil].freeze,
    [:sum, nil].freeze,
  ].freeze


  # Query for case tags
  QueryCaseTags = [
    ['status', :status, :boolean].freeze,
    ['template', :template, :boolean].freeze,
    ['grantee', :grantee, :string].freeze,
    ['purpose', :purpose, :string].freeze,
  ].freeze


  # Case Tags list
  ListCaseTags = [
    [:tag, :case].freeze,
    [:count, nil].freeze,
  ].freeze


  # Entry tags query options
  QueryEntryTags = [
    ['caseid', :caseid, :string].freeze,
    ['purpose', :purpose, :string].freeze,
  ].freeze


  # Entry Tags list
  ListEntryTags = [
    [:tag, :entry].freeze,
    [:count, nil].freeze,
  ].freeze


  # Action Tag query
  QueryActionTags = [
    ['caseid', :caseid, :string].freeze,
    ['assigned', :assigned, :string].freeze,
    ['status', :status, :boolean].freeze,
    ['flag', :flag, :boolean].freeze,
    ['before', :before, :time].freeze,
    ['after', :after, :time].freeze,
    ['purpose', :purpose, :string].freeze,
  ].freeze


  # Action Tags list
  ListActionTags = [
    [:tag, :action].freeze,
    [:count, nil].freeze
  ].freeze


  # Index tags query
  QueryIndexTags = [
    ['caseid', :caseid, :string].freeze,
    ['purpose', :purpose, :string].freeze,
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
    env['icfs.page'] = 'Case Create'
    api = env['icfs']
    tid = _util_case(env)
    _verb_getpost(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'
      tpl = api.case_read(tid)
      tpl['title'] = ''
      parts = [
        _form_create(env),
        _form_case(env, tpl),
        _form_entry(env, tid, nil),
      ]
      body = [
        _div_nav(env),
        _div_desc(
          'Create New Case',
          '<i>template:</i> %s' % Rack::Utils.escape_html(tid),
        ),
        _div_form(env, '/case_create/', tid, parts, 'Create Case')
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)

      # process
      cse = _post_case(env, para)
      cid =  para['create_cid']
      cse['template'] = (para['create_tmpl'] == 'true') ? true : false

      # process entry
      ent = _post_entry(env, para)
      Items.validate(tid, 'Template ID', Items::FieldCaseid)
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
    env['icfs.page'] = 'Case Edit'
    cid = _util_case(env)
    api = env['icfs']
    _verb_getpost(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'
      cse = api.case_read(cid)
      parts = [
        _form_case(env, cse),
        _form_entry(env, cid, nil, {enable: false}),
      ]
      body = [
        _div_nav(env),
        _div_desc('Edit Case', ''),
        _div_form(env, '/case_edit/', cid, parts, 'Record Case'),
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)

      # process
      cse = _post_case(env, para)
      ent = _post_entry(env, para)
      cse['caseid'] = cid
      cse_old = api.case_read(cid)
      cse['template'] = cse_old['template']
      api.record(ent, nil, nil, cse)

      # display the case
      body = [
        _div_nav(env),
        _div_case(env, cse),
      ]
      body << _div_entry(env, ent) if ent
      return _resp_success(env, body.join(''))
    end
  end # def _call_case_edit()


  ###############################################
  # Edit an entry
  #
  def _call_entry_edit(env)
    env['icfs.page'] = 'Entry Edit'
    api = env['icfs']
    _verb_getpost(env)

    cid = _util_case(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'
      enum = _util_num(env, 2)
      anum = _util_num(env, 3)

      # entry or action specified
      if enum != 0
        desc = 'Edit Entry'
        ent = api.entry_read(cid, enum)
      elsif anum != 0
        desc = 'New Entry in Action'
        act = api.action_read(cid, anum)
      else
        desc = 'New Entry'
      end

      # see if editing is possible
      unless( api.access_list(cid).include?(ICFS::PermWrite) || (
        (anum != 0) && api.tasked?(cid, anum)))
        raise(Error::Perms, 'Not able to edit this entry.')
      end

      # build form
      opts = {}
      opts[:enable] = true if enum == 0
      opts[:action] = anum if anum
      parts = [ _form_entry(env, cid, ent, opts) ]
      body = [
        _div_nav(env),
        _div_desc(desc, ''),
        _div_form(env, '/entry_edit/', cid, parts, 'Record Entry'),
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)

      # process
      ent = _post_entry(env, para)
      raise(Error::Values, 'Entry form not enabled') unless ent
      ent['caseid'] = cid
      api.record(ent, nil, nil, nil)

      # display the entry
      body = [
        _div_nav(env),
        _div_entry(env, ent)
      ]
      return _resp_success(env, body.join(''))
    end
  end # def _call_entry_edit()


  ###############################################
  # Edit an Index
  #
  def _call_index_edit(env)
    env['icfs.page'] = 'Index Edit'
    api = env['icfs']
    _verb_getpost(env)

    cid = _util_case(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'

      # see if editing is possible
      unless api.access_list(cid).include?(ICFS::PermWrite)
        raise(Error::Perms, 'Not able to edit this index.')
      end

      xnum = _util_num(env, 2)
      idx = api.index_read(cid, xnum) if xnum != 0
      parts = [
        _form_index(env, cid, idx),
        _form_entry(env, cid, nil, {enable: false}),
      ]
      desc = idx ? 'Edit Index' : 'New Index'
      body = [
        _div_nav(env),
        _div_desc(desc, ''),
        _div_form(env, '/index_edit/', cid, parts,
          'Record Index'),
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)

      # process
      ent = _post_entry(env, para)
      idx = _post_index(env, para)
      idx['caseid'] = cid
      api.record(ent, nil, idx, nil)

      # display the index
      body = [
        _div_nav(env),
        _div_index(env, idx),
      ]
      body << _div_entry(env, ent) if ent
      return _resp_success(env, body.join(''))
    end
  end # def _call_index_edit()


  ###############################################
  # Edit an Action
  #
  def _call_action_edit(env)
    env['icfs.page'] = 'Action Edit'
    api = env['icfs']
    _verb_getpost(env)

    cid = _util_case(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'
      anum = _util_num(env, 2)

      # see if editing is possible
      unless( api.access_list(cid).include?(ICFS::PermAction) ||
              ((anum != 0) && api.tasked?(cid, anum)) )
        raise(Error::Perms, 'Not able to edit this action.')
      end

      act = api.action_read(cid, anum) if anum != 0
      opts = {enable: false}
      opts[:action] = anum if act
      parts = [
        _form_action(env, cid, act),
        _form_entry(env, cid, nil, opts),
      ]
      desc = act ? 'Edit Action' : 'New Action'
      body = [
        _div_nav(env),
        _div_desc(desc, ''),
        _div_form(env, '/action_edit/', cid, parts,
          'Record Action'),
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)

      # process
      ent = _post_entry(env, para)
      act = _post_action(env, para)
      act['caseid'] = cid
      api.record(ent, act, nil, nil)

      # display the index
      body = [
        _div_nav(env),
        _div_action(env, act),
      ]
      body << _div_entry(env, ent) if ent
      return _resp_success(env, body.join(''))
    end
  end # def _call_action_edit()


  ###############################################
  # Edit configuration
  #
  def _call_config_edit(env)
    env['icfs.page'] = 'Config Edit'
    api = env['icfs']
    cfg = api.config
    _verb_getpost(env)

    # get the form
    if env['REQUEST_METHOD'] == 'GET'
      parts = [ _form_config(env) ]
      body = [
        _div_nav(env),
        _div_desc('Edit Configuration', ''),
        _div_form(env, '/config_edit/', nil, parts,
          'Save Config'),
      ].join('')
      return _resp_success(env, body)

    # post the form
    elsif env['REQUEST_METHOD'] == 'POST'
      para = _util_post(env)
      _post_config(env, para).each{|key, val| cfg.set(key,val) }
      cfg.save
      api.user_flush()

      # display the index
      body = [
        _div_nav(env),
        _div_desc('Edit Configuration', 'Settings saved'),
        _div_info(env),
      ].join('')
      return _resp_success(env, body)
    end
  end # def _call_config_edit()


  ###############################################
  # User Home page
  def _call_home(env)
    env['icfs.page'] = 'Home'
    _verb_get(env)
    body = [
      _div_nav(env),
      _div_desc('User Home', ''),
      _div_home(env),
    ].join('')
    return _resp_success(env, body)
  end # def _call_home()


  ###############################################
  # Display a Case
  #
  def _call_case(env)
    env['icfs.page'] = 'Case View'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    lnum = _util_num(env, 2)
    cse = api.case_read(cid, lnum)
    ent = api.entry_read(cid, cse['entry']) if cse['entry']
    msg = (lnum != 0) ? 'This is a historical version of this Case' : ''
    body = [
      _div_nav(env),
      _div_desc('Case Information', msg),
      _div_case(env, cse),
    ]
    body << _div_entry(env, ent) if ent
    return _resp_success(env, body.join(''))
  end # def _call_case()


  ###############################################
  # Display an Entry
  #
  def _call_entry(env)
    env['icfs.page'] = 'Entry View'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    enum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Entry requested') if enum == 0
    ent = api.entry_read(cid, enum, lnum)
    if lnum != 0
      msg = 'This is a historical version of this Entry'
    else
      msg = ''
    end
    body = [
      _div_nav(env),
      _div_desc('View Entry', msg),
      _div_entry(env, ent),
    ].join('')
    return _resp_success(env, body)
  end # def _call_entry()


  ###############################################
  # Display a Log
  #
  def _call_log(env)
    env['icfs.page'] = 'Log View'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    lnum = _util_num(env, 2)
    raise(Error::Interface, 'No log requested') if lnum == 0
    log = api.log_read(cid, lnum)
    body = [
      _div_nav(env),
      _div_desc('View Log', ''),
      _div_log(env, log)
    ].join('')
    return _resp_success(env, body)
  end # def _call_log()


  ###############################################
  # Display an Action
  #
  def _call_action(env)
    env['icfs.page'] = 'Action View'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    anum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Action requested') if anum == 0

    act = api.action_read(cid, anum, lnum)
    ent = api.entry_read(cid, act['entry']) if act['entry']
    ent_div = _div_entry(env, ent) if ent

    # historical
    if lnum != 0
      msg = 'This is a historical version of this Action'
      list_div = ''

    # current
    else
      msg = ''
      query = {
        caseid: cid,
        action: anum,
        purpose: 'Action Entries',
      }
      resp = api.entry_search(query)
      list_div = _div_list(env, resp, ListEntry) +
          _div_page(resp){|qu, txt| _a_entry_search(env, qu, txt)}
    end

    # display
    body = [
      _div_nav(env),
      _div_desc('View Action', msg),
      _div_action(env, act),
      ent_div,
      list_div
    ]
    return _resp_success(env, body.join(''))
  end # def _call_action()


  ###############################################
  # Display an Index
  #
  def _call_index(env)
    env['icfs.page'] = 'Index View'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)
    xnum = _util_num(env, 2)
    lnum = _util_num(env, 3)
    raise(Error::Interface, 'No Index requested') if xnum == 0


    idx = api.index_read(cid, xnum, lnum)
    ent = api.entry_read(cid, idx['entry']) if idx['entry']
    ent_div = ent ? _div_entry(env, ent) : ''

    # historical index
    if lnum != 0
      msg = 'This is a historical version of this Index'
      list_div = ''

    # current index
    else
      msg = ''
      query = {
        caseid: cid,
        index: xnum
      }
      resp = api.entry_search(query)
      list_div = _div_list(env, resp, ListEntry) +
        _div_page(resp){|qu, txt| _a_entry_search(env, qu, txt)}
    end

    # display
    body = [
      _div_nav(env),
      _div_desc('View Index', msg),
      _div_index(env, idx),
      ent_div,
      list_div
    ]
    return _resp_success(env, body.join(''))
  end # def _call_index()


  ###############################################
  # Get a file
  def _call_file(env)
    env['icfs.page'] = 'File Download'
    api = env['icfs']
    _verb_get(env)
    cid = _util_case(env)

    # get filename
    cmps = env['icfs.cmps']
    if cmps.size < 3 || cmps[2].empty?
      raise(Error::Interface, 'No file specified in the URL')
    end
    fnam = Rack::Utils.unescape(cmps[2])
    ma = /^(\d+)-(\d+)-(\d+)-(.+)$/.match fnam
    if !ma
      raise(Error::Interface, 'File not properly specified in URL')
    end
    enum = ma[1].to_i
    lnum = ma[2].to_i
    fnum = ma[3].to_i
    ext = ma[4].rpartition('.')[2]

    # get MIME-type by extension
    if ext.empty?
      mime = 'application/octet-stream'
    else
      mime = Rack::Mime.mime_type('.' + ext)
    end

    # return the file
    file = api.file_read(cid, enum, lnum, fnum)
    fr = Web::FileResp.new(file)
    headers = {
      'Content-Length' => file.size.to_s,
      'Content-Type' => mime,
      'Content-Disposition' => 'attachment',
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
            purpose: 'Case Entries',
          }, 'Entries'),
        _a_index_search(env, {
            caseid: cid,
            purpose: 'Case Indexes',
          }, 'Indexes'),
        _a_stats(env, {
            caseid: cid,
            purpose: 'Case Stats',
          }, 'Stats'),
        _a_entry_tags(env, {
            caseid: cid,
            purpose: 'Entry Tags',
          }, 'Entry Tags'),
        _a_index_tags(env, {
            caseid: cid,
            purpose: 'Index Tags',
          }, 'Index Tags'),
        _a_entry_edit(env, cid, 0, 0, 'New Entry'),
        _a_index_edit(env, cid, 0, 'New Index'),
      ]

    # no case
    else
      tc = ''
      tabs = [
        _a_action_search(env, {
            assigned: unam,
            status: true,
            flag: true,
            purpose: 'Flagged Actions',
          }, 'Actions'),
        _a_case_search(env, {
            grantee: unam,
            status: true,
            template: false,
            purpose: 'Open Cases',
          }, 'Cases'),
        _a_stats(env, {
            credit: unam,
            after: Time.now.to_i - 60*60*24*30,
            purpose: 'User Stats - Last 30 days',
          }, 'Stats'),
        _a_config_edit(env, 'Config'),
        _a_info(env, 'Info'),
      ]
    end

    # tab divs
    tabs = tabs.map{|aa| DivNavTab % aa}.join('')

    return DivNav % [
      _a_home(env, 'ICFS'),
      tc,
      tabs
    ]
  end # def _div_nav()


  # navbar div
  DivNav = '
  <div class="nav">
    <div class="nav-icfs">%s</div>
    <div class="nav-case">%s</div>%s
  </div>'


  # navbar tab
  DivNavTab = '
    <div class="nav-tab">%s</div>'


  ###############################################
  # Message div
  #
  def _div_msg(env, msg)
    DivMsg % msg
  end # def _div_msg()


  # message div
  DivMsg = '
  <div class="message">%s
  </div>'


  ###############################################
  # Info div
  #
  def _div_info(env)
    api = env['icfs']
    tz = api.config.get('tz')

    # roles/groups/perms
    roles = api.roles.map{|rol| DivInfoList % Rack::Utils.escape_html(rol)}
    grps = api.groups.map{|grp| DivInfoList % Rack::Utils.escape_html(grp)}
    perms = api.perms.map{|pm| DivInfoList % Rack::Utils.escape_html(pm)}

    # global stats
    gstats = api.gstats.map{|st| DivInfoList % Rack::Utils.escape_html(st)}

    return DivInfo % [
      Rack::Utils.escape_html(tz),
      Rack::Utils.escape_html(api.user),
      roles.join(''),
      grps.join(''),
      perms.join(''),
      gstats.join(''),
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
  </div>'


  # List items in the info div
  DivInfoList = '
          <div>%s</div>'


  # Column classes by symbol
  ListColClass = {
    entry: 'list-int',
    action: 'list-int',
    index: 'list-int',
    indexes: 'list-int-sm',
    case: 'list-int',
    log: 'list-int',
    tags: 'list-int-sm',
    tag: 'list-tag',
    stats: 'list-int-sm',
    time: 'list-time',
    title: 'list-title',
    caseid: 'list-caseid',
    stat: 'list-stat',
    sum: 'list-float',
    count: 'list-int',
    files: 'list-int-sm',
    user: 'list-usergrp',
  }.freeze


  ###############################################
  # Search results list div
  #
  # @param env [Hash] Rack environment
  # @param resp [Hash] Search response
  # @param list [Array] List of object items to display and how
  #
  def _div_list(env, resp, list)
    return _div_msg(env, 'No results found') if resp[:list].size == 0

    # did we query with caseid?
    qcid = resp[:query].key?(:caseid)

    # copy the query
    qu = resp[:query].dup

    # header row
    hcols = list.map do |sym, opt|
      if sym == :caseid && qcid
        ''
      else
        DivListHeadItems[sym]
      end
    end
    head = DivListHead % hcols.join('')

    # do we do relative times?
    cfg = env['icfs'].config
    rel_time = cfg.get('rel_time')

    # search results into rows
    rows = resp[:list].map do |sr|
      obj = sr[:object]
      cid = obj[:caseid]

      cols = list.map do |sym, opt|
        it = obj[sym]
        cc = ListColClass[sym]
        ct = nil

        # snippets are special non-column, not in the object itself
        if sym == :snippet
          if sr[:snippet]
            next( DivListItem % ['list-snip', sr[:snippet]])
          else
            next('')
          end

        # redacted result
        elsif it.nil?
          next( DivListItem % [cc, '&mdash;'])
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
            cd = (it != 0) ? _a_entry(env, cid, it, obj[:log], it.to_s) : ''
          else
            cd = it.to_s
          end

        # action
        when :action
          case opt
          when :current
            cd = (it == 0) ? '' :  _a_action(env, cid, it, 0, it.to_s)
          when :log
            cd = (it != 0) ? _a_action(env, cid, it, obj[:log], it.to_s) : ''
          else
            cd = it == 0 ? '' : it.to_s
          end

        # index
        when :index
          case opt
          when :current
            cd = _a_index(env, cid, it, 0, it.to_s)
          when :log
            if it != 0
              cd = _a_index(env, cid, it, obj[:log], it.to_s)
            else
              cd = ''
            end
          else
            cd = it.to_s
          end

        # case
        when :case
          case opt
          when :log
            cd = (it != 0) ? _a_case(env, cid, obj[:log], 'Y') : ''
          else
            cd = ''
          end

        # indexes
        when :indexes
          cd = (it == 0) ? '' : it.to_s

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
            cd = ''
          else
            cd = it.size.to_s
          end

        # tag - the result of a tags aggregation
        when :tag
          qu[:tags] = it

          case opt
          when :entry
            qu[:purpose] = 'Entry Tag Search'
            cd = _a_entry_search(env, qu, it)
          when :index
            qu[:purpose] = 'Index Tag Search'
            cd = _a_index_search(env, qu, it)
          when :case
            qu[:purpose] = 'Case Tag Search'
            cd = _a_case_search(env, qu, it)
          when :action
            qu[:purpose] = 'Action Tag Search'
            cd = _a_action_search(env, qu, it)
          end

        # time
        when :time
          if rel_time
            tme = ICFS.time_relative(it)
            ct = ICFS.time_weekday(it, cfg)
          else
            tme = ICFS.time_weekday(it, cfg)
          end

          case opt
          when :entry
            cd = _a_entry(env, cid, obj[:entry], 0, tme)
          when :log
            cd = _a_log(env, cid, obj[:log], tme)
          else
            cd = tme
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
          qu[:purpose] = 'Entry Stat Search'
          cd = _a_entry_search(env, qu, it)

        # sum - only on stats aggregation
        when :sum
          cd = it.to_s

        # count - only on stats aggregation
        when :count
          cd = it.to_s

        # files
        when :files
          cd = it == 0 ? '' : it.to_s

        # user
        when :user
          cd = Rack::Utils.escape_html(it)

        # stats
        when :stats
          cd = it == 0 ? '' : it.to_s

        # huh?
        else
          raise NotImplementedError, sym.to_s
        end

        if cd
          if ct
            DivListItemTitle % [cc, ct, cd]
          else
            DivListItem % [cc, cd]
          end
        else
          ''
        end
      end

      DivListRow % cols.join('')
    end

    return DivList % [head, rows.join('')]

  end # def _div_list()


  # Search results list
  DivList = '
  <div class="list">%s%s
  </div>'

  # Search results row
  DivListRow = '
    <div class="list-row">%s
    </div>'

  # Search results header
  DivListHead = '
    <div class="list-head">%s
    </div>'

  # Search results header items
  DivListHeadItems = {
    tags: '
      <div class="list-int-sm" title="Number of tags">#T</div>',
    tag: '
      <div class="list-tag">Tag</div>',
    entry: '
      <div class="list-int">Entry</div>',
    index: '
      <div class="list-int">Index</div>',
    indexes: '
      <div class="list-int-sm" title="Number of Indexes">#I</div>',
    action: '
      <div class="list-int">Action</div>',
    case: '
      <div class="list-int">Case</div>',
    log: '
      <div class="list-int">Log</div>',
    title: '
      <div class="list-title">Title</div>',
    caseid: '
      <div class="list-caseid">Case ID</div>',
    stats: '
      <div class="list-int-sm" title="Number of stats">#S</div>',
    time: '
      <div class="list-time">Date/Time</div>',
    stat: '
      <div class="list-stat">Stat Name</div>',
    sum: '
      <div class="list-float">Total</div>',
    count: '
      <div class="list-int">Count</div>',
    files: '
      <div class="list-int-sm" title="Number of files">#F</div>',
    user: '
      <div class="list-usergrp">User</div>',
    snippet: ''
  }.freeze

  # search results item
  DivListItem = '
      <div class="%s">%s</div>'

  # search results item with title
  DivListItemTitle = '
      <div class="%s" title="%s">%s</div>'


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
  </div>'


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
        ary << '<b>%d</b>' % page
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
      prev_page = ''
    else
      query[:page] = cur - 1
      if pr
        prev_page = pr.call(query, '(Prev)')
      else
        prev_page = yield(query, '(Prev)')
      end
    end

    # next
    if cur == disp_pages
      next_page = ''
    else
      query[:page] = cur + 1
      if pr
        next_page = pr.call(query, '(Next)')
      else
        next_page = yield(query, '(Next)')
      end
    end

    return DivPage % [
      prev_page, ary.join(' '), next_page,
      hits, tot_pages
    ]
  end # def _div_page()


  # Pageing div
  DivPage = '
  <div class="pagenav">
    &lt;&lt; %s %s %s &gt;&gt;<br>
    Hits: %d Pages: %d
  </div>'


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
            purpose: 'Open Cases'
          }, 'open'),
        _a_case_search(env, {
            grantee: ug,
            status: false,
            template: false,
            purpose: 'Closed Cases'
          }, 'closed'),
        _a_case_search(env, {
              grantee: ug,
              perm: ICFS::PermAction,
              status: true,
              template: false,
              purpose: 'Action Manager Cases'
            }, 'action mgr'),
        _a_case_tags(env, {
            grantee: ug,
            status: true,
            template: false,
            purpose: 'Open Case Tags'
          }, 'tags'),
      ].map{|lk| DivHomeLink % lk }.join('')

      al = [
        _a_action_search(env, {
            assigned: ug,
            status: true,
            flag: true,
            purpose: 'Flagged Actions'
          }, 'flagged'),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            before: now,
            sort: 'time_asc',
            purpose: 'Actions - Past Date',
          }, 'past'),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            after: now,
            sort: 'time_desc',
            purpose: 'Actions - Future Date',
          }, 'future'),
        _a_action_search(env, {
            assigned: ug,
            status: true,
            purpose: 'Open Actions'
          }, 'all open'),
        _a_action_tags(env, {
            assigned: ug,
            status: true,
            purpose: 'Open Action Tags'
          }, 'tags'),
      ].map{|lk| DivHomeLink % lk }.join('')

      ol = [
        _a_case_search(env, {
          grantee: ug,
          perm: ICFS::PermManage,
          status: true,
          template: false,
          purpose: 'Managed Cases',
          }, 'managed'),
        _a_case_search(env, {
            grantee: ug,
            perm: ICFS::PermManage,
            status: true,
            template: true,
            purpose: 'Templates',
          }, 'templates'),
        _a_stats(env, {
            credit: ug,
            after: Time.now.to_i - 60*60*24*30,
            purpose: 'User/Role Stats - 30 days',
          }, '30-day stats'),
      ].map{|lk| DivHomeLink % lk }.join('')


      DivHomeUr % [Rack::Utils.escape_html(ug), al, cl, ol ]
    end

    DivHome % useract.join('')
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
  </div>'


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
    </div>'


  # Home Link
  DivHomeLink = '
        <div class="list-text-s">%s</div>'


  ###############################################
  # Case Create Form
  #
  def _form_create(env)
    [ FormCaseCreate, '' ]
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
    </div>'


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
      parts.join(''),
      button,
    ]
  end # def _div_form()

  # Form
  DivForm = '
  <div class="form"><form method="post" action="%s"
      enctype="multipart/form-data" accept-charset="utf-8">
%s
    <input class="submit" type="submit" value="%s">
  </form></div>'



  ###############################################
  # Case div
  #
  def _div_case(env, cse)
    api = env['icfs']
    urg = api.urg
    cid = cse['caseid']
    al = api.access_list(cid)

    status = cse['status'] ? 'Open' : 'Closed'
    template = cse['template'] ? 'Yes' : 'No'

    # case links
    links = [
      _a_log_search(env, {caseid: cid, case_edit: true}, 'History of Case'),
      _a_log_search(env, {caseid: cid}, 'All Logs'),
    ]
    if al.include?(ICFS::PermManage)
      links << _a_case_edit(env, cid, 'Edit This Case')
      if cse['template']
        links << _a_case_create(env, cid, 'Create New Case')
      end
    end
    links.map!{|aa| DivCaseLink % aa}

    # action section
    if al.include?(ICFS::PermAction)
      now = Time.now.to_i
      actions = [
        _a_action_edit(env, cid, 0, 'New Action'),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            flag: true,
            purpose: 'Flagged Actions',
          }, 'List flagged'),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            before: now,
            sort: 'time_asc',
            purpose: 'Actions - Past Date',
          }, 'List past'),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            after: now,
            sort: 'time_desc',
            purpose: 'Actions - Future Date',
          }, 'List future'),
        _a_action_search(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            purpose: 'Open Actions',
          }, 'List open'),
        _a_action_tags(env, {
            caseid: cid,
            assigned: ICFS::UserCase,
            status: true,
            purpose: 'Open Action Tags',
          }, 'Action tags'),
      ].map{|lk| DivCaseLink % lk}
      actions = DivCaseActions % actions.join('')
    else
      actions = ''
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
      DivCaseAccess % [ pm, ugl.join('') ]
    end

    # stats
    if cse['stats']
      stats = cse['stats'].map do |st|
        DivCaseStatEach % _a_entry_search(env, { caseid: cid, stat: st,
          purpose: 'Entries with Stat' },
          Rack::Utils.escape_html(st) )
      end
      stats = DivCaseStats % stats.join('')
    else
      stats = ''
    end

    return DivCase % [
      Rack::Utils.escape_html(cid),
      _a_log(env, cid, cse['log'], cse['log'].to_s),
      status,
      template,
      links.join(''),
      Rack::Utils.escape_html(cse['title']),
      acc.join(''),
      tags.join(''),
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
  </div>'


  # Case div action links
  DivCaseActions = '
      <div class="sect">
        <div class="sect-head">Actions</div>%s
      </div>'


  # Case div links
  DivCaseLink = '
        <div>%s</div>'

  # Case div each access
  DivCaseAccess = '
          <div class="list-row">
            <div class="list-perm">%s</div>
            <div class="list-vert list-usergrp">%s
            </div>
          </div>'


  # Case div each grant
  DivCaseGrant = '
            <div>%s</div>'


  # Case div each tag
  DivCaseTag = '
        <div class="item-tag">%s</div>'


  # Case div stats section
  DivCaseStats = '
      <div class="sect">
        <div class="sect-head">Stats</div>
        <div class="list">%s
        </div>
      </div>'


  # Case div each stat
  DivCaseStatEach = '
          <div class="list-perm">%s</div>'


  ###############################################
  # Entry div
  #
  def _div_entry(env, ent)
    api = env['icfs']
    cid = ent['caseid']

    links = []

    enum = ent['entry']
    links << _a_entry_edit(env, cid, enum, 0, 'Edit This Entry')

    lnum = ent['log']
    links << _a_log_search(env, {
          'caseid' => cid,
          'entry' => enum,
          'purpose' => 'History of Entry',
        }, 'History of Entry')

    if ent['action']
      anum = ent['action']
      action = DivEntryAction % _a_action(env, cid, anum, 0, anum.to_s)
      links << _a_entry_edit(env, cid, 0, anum, 'New Entry in Action')
    else
      action = ''
    end

    if ent['index']
      indexes = ent['index'].map do |xnum|
        idx = api.index_read(cid, xnum)
        DivEntryIndexEach % _a_index(env, cid, xnum, 0, idx['title'])
      end
      index = DivEntryIndex % indexes.join('')
    else
      index = ''
    end

    tags = ent['tags'].map do |tag|
      DivEntryTag % _a_entry_search(env, {
          'caseid' => cid,
          'tags' => tag,
          'purpose' => 'Tag Entries',
        }, tag)
    end

    if ent['perms']
      pa = ent['perms'].map do |pm|
        DivEntryPermEach % Rack::Utils.escape_html(pm)
      end
      perms = DivEntryPerms % pa.join("\n")
    else
      perms = ''
    end

    if ent['stats']
      sa = ent['stats'].map do |st|
        ca = st['credit'].map do |ug|
          Rack::Utils.escape_html(ug)
        end
        DivEntryStatEach % [
          Rack::Utils.escape_html(st['name']),
          st['value'],
          ca.join(', ')
        ]
      end
      stats = DivEntryStats % sa.join("\n")
    else
      stats = ''
    end

    if ent['files']
      fa = ent['files'].map do |fd|
        DivEntryFileEach % _a_file(env, cid, enum, fd['log'],
          fd['num'], fd['name'], fd['name'])
      end
      files = DivEntryFiles % fa.join("\n")
    else
      files = ''
    end

    return DivEntry % [
      _a_case(env, cid, 0, cid),
      _a_entry(env, cid, enum, 0, enum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      Rack::Utils.escape_html(ent['user']),
      action,
      links.map{|lk| DivEntryLink % lk }.join(''),
      Rack::Utils.escape_html(ent['title']),
      ICFS.time_weekday(ent['time'], api.config),
      Rack::Utils.escape_html(ent['content']),
      tags.join("\n"),
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
  </div>'


  # entry tag each
  DivEntryTag = '
          <div>%s</div>'


  # entry link each
  DivEntryLink = '
          <div>%s</div>'


  # entry action
  DivEntryAction = '
      <div class="list-row">
        <div class="list-label">Action:</div>
        <div class="list-int">%s</div>
      </div>'


  # entry index
  DivEntryIndex = '
      <div class="sect">
        <div class="sect-head">Indexes</div>
        <div class="index-list">%s
        </div>
      </div>'


  # entry index each
  DivEntryIndexEach = '
          <div>%s</div>'


  # entry perms
  DivEntryPerms = '
      <div class="sect">
        <div class="sect-head">Permissions</div>
        <div class="perms-list">%s
        </div>
      </div>'


  # entry perm each
  DivEntryPermEach = '
          <div>%s</div>'


  # entry stats
  DivEntryStats = '
      <div class="sect">
        <div class="sect-head">Stats</div>
        <div class="stats-list">%s
        </div>
      </div>'


  # entry each stat
  DivEntryStatEach = '
          <div>%s %f %s</div>'


  # entry files
  DivEntryFiles = '
      <div class="sect">
        <div class="sect-head">Files</div>
        <div class="files-list">%s
        </div>
      </div>'


  # entry each file
  DivEntryFileEach = '
          <div>%s</div>'


  ###############################################
  # Log div
  #
  def _div_log(env, log)
    cid = log['caseid']
    lnum = log['log']

    navp = (lnum == 1) ? 'prev' : _a_log(env, cid, lnum-1, 'prev')
    navn = _a_log(env, cid, lnum + 1, 'next')

    if log['case']
      chash = DivLogCase % _a_case(env, cid, lnum, log['case']['hash'])
    else
      chash = ''
    end

    if log['entry']
      enum = log['entry']['num']
      entry = DivLogEntry % [
        _a_entry(env, cid, enum, lnum, log['entry']['hash']),
        enum
      ]
    else
      entry = ''
    end

    if log['action']
      action = DivLogAction % [
        _a_action(env, cid, log['action']['num'], lnum, log['action']['hash']),
        log['action']['num'],
      ]
    else
      action = ''
    end

    if log['index']
      index = DivLogIndex % [
        _a_index(env, cid, log['index']['num'], lnum, log['index']['hash']),
        log['index']['num'],
      ]
    else
      index = ''
    end

    if log['files_hash']
      ha = log['files_hash']
      fa = []
      ha.each_index do |ix|
        fa << DivLogFileEach % [
            _a_file(env, cid, enum, lnum, ix, 'file.bin', ha[ix]),
            ix
        ]
      end
      files = DivLogFiles % fa.join("\n")
    else
      files = ''
    end

    return DivLog % [
      Rack::Utils.escape_html(cid),
      log['log'],
      navp,
      navn,
      ICFS.time_weekday(log['time'], env['icfs'].config),
      Rack::Utils.escape_html(log['user']),
      log['prev'],
      entry,
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
      </div>%s%s%s%s%s
    </div>
  </div>'


  # log entry
  DivLogEntry = '
      <div class="list-row">
        <div class="list-label">Entry:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>'


  # log action
  DivLogAction = '
      <div class="list-row">
        <div class="list-label">Action:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>'


  # log index
  DivLogIndex = '
      <div class="list-row">
        <div class="list-label">Index:</div>
        <div class="list-hash">%s</div>
        <div class="list-int">%d</div>
      </div>'


  # log case
  DivLogCase = '
      <div class="list-row">
        <div class="list-label">Case:</div>
        <div class="list-hash">%s</div>
      </div>
  '

  # log file
  DivLogFiles = '
      <div class="list-row">
        <div class="list-label">Files:</div>
        <div class="files-list">%s
        </div>
      </div>'


  # log file
  DivLogFileEach = '
          <div>
            <div class="list-hash">%s</div>
            <div class="list-int">%d</div>
          </div>'


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
    links << _a_action_edit(env, cid, anum, 'Edit this Action')

    lnum = act['log']
    links << _a_log_search(env, {
        'caseid' => cid,
        'action' => anum,
        'purpose' => 'Action History',
      }, 'History of Action')

    links << _a_entry_edit(env, cid, 0, anum, 'New Entry in Action')

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
        edit ? 'task-ed' : 'task-ro',
        Rack::Utils.escape_html(tk['assigned']),
        Rack::Utils.escape_html(tk['title']),
        tk['status'] ? 'Open' : 'Closed',
        tk['flag'] ? 'Raised' : 'Normal',
        ICFS.time_weekday(tk['time'], api.config),
        tags.join(''),
      ]
    end

    return DivAction % [
      _a_case(env, cid, 0, cid),
      _a_action(env, cid, anum, 0, anum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      links.map{|lk| DivActionLink % lk }.join(''),
      tasks.join('')
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

  </div>'


  # Action link
  DivActionLink = '
          <div>%s</div>'


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
      </div>'


  # Action Tag
  DivActionTag = '
            <div>%s</div>'


  ###############################################
  # Index div
  #
  def _div_index(env, idx)
    cid = idx['caseid']

    links = []
    xnum = idx['index']
    links << _a_index_edit(env, cid, xnum, 'Edit This Index')

    lnum = idx['log']
    links << _a_log_search(env, {
          'caseid' => cid,
          'index' => xnum,
          'purpose' => 'Index History',
        }, 'History of Index')

    tags = idx['tags'].map do |tg|
      DivIndexTag % _a_index_search(env, {
          'caseid' => cid,
          'tags' => tg,
          'purpose' => 'Index Entries',
        }, tg)
    end

    return DivIndex % [
      _a_case(env, cid, 0, cid),
      _a_index(env, cid, xnum, 0, xnum.to_s),
      _a_log(env, cid, lnum, lnum.to_s),
      links.map{|lk| DivIndexLink % lk }.join(''),
      Rack::Utils.escape_html(idx['title']),
      Rack::Utils.escape_html(idx['content']),
      tags.join(''),
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
    </div>'


  # Index Links
  DivIndexLink = '
          <div>%s</div>'

  # Index tags
  DivIndexTag = '
            <div>%s</div>'


  ###############################################
  # Description div for queries
  #
  def _div_query(env, type, sup, query, disp=false)
    cfg = env['icfs'].config

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
        para = val ? 'true' : 'false'
      when :integer
        para = val.to_s
      when :time
        para = ICFS.time_local(val, cfg)
      else
        raise NotImplementedError, pr.to_s
      end

      list << '<i>%s:</i> %s' % [sym, para]
    end
    if list.empty?
      paras = ''
    else
      paras = ' &ndash; ' + list.join(', ')
    end

    # enable value
    value = disp ? 'true' : 'false'

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
    <input name="que-enable" id="que-ena" type="hidden" value="%s">'


###########################################################
# Generate forms
###########################################################


  ###############################################
  # Query form
  #
  def _form_query(env, sup, query, act, disp=false)
    cfg = env['icfs'].config

    # supported params
    inputs = sup.map do |txt, sym, pr|

      case sym
      when :caseid
        ilabel = 'Case ID'
        iclass = 'form-caseid'
        ihint = 'Filter for a specific case.'
      when :title
        ilabel = 'Title'
        iclass = 'form-title'
        ihint = 'Text search within the title.'
      when :prefix
        ilabel = 'Prefix'
        iclass = 'form-title'
        ihint = 'Filter for titles starting with fixed text.'
      when :content
        ilabel = 'Content'
        iclass = 'form-content'
        ihint = 'Text search within the content.'
      when :tags
        ilabel = 'Tag'
        iclass = 'form-tag'
        ihint = 'Filter for only a specific tag.'
      when :action
        ilabel = 'Action'
        iclass = 'form-int'
        ihint = 'Filter for a specific action (by number).'
      when :before
        ilabel = 'Before'
        iclass = 'form-time'
        ihint = 'Filter for items occuring before this date and time.'
      when :after
        ilabel = 'After'
        iclass = 'form-time'
        ihint = 'Filter for items occuring after this date and time.'
      when :credit
        ilabel = 'Credit'
        iclass = 'form-usergrp'
        ihint = 'Filter for stats crediting this user or role.'
      when :size
        ilabel = 'Size'
        iclass = 'form-int'
        ihint = 'Number of results to be returned per page.'
      when :page
        next
      when :sort
        ilabel = 'Sort'
        iclass = 'form-sort'
        ihint = 'How to sort the results.'
      when :purpose
        next
      when :user
        ilabel = 'User'
        iclass = 'form-usergrp'
        ihint = 'Filter for logs authored by this user.'
      when :grantee
        ilabel = 'Grantee'
        iclass = 'form-usergrp'
        ihint = 'Filter for cases granting this user or role a permission.'
      when :perm
        ilabel = 'Permission'
        iclass = 'form-perm'
        ihint = 'Filter for cases granting this permission.'
      when :case_edit
        ilabel = 'Case edited'
        iclass = 'form-boolean'
        ihint = 'Filter for logs recoding a case.'
      when :entry
        ilabel = 'Entry'
        iclass = 'form-int'
        ihint = 'Filter for logs recording specified entry (by number).'
      when :index
        ilabel = 'Index'
        iclass = 'form-int'
        ihint = 'Filter for specified index (by number).'
      when :assigned
        ilabel = 'Assigned'
        iclass = 'form-usergrp'
        ihint = 'Filter for tasks assigned to specified user or role.'
      when :status
        ilabel = 'Status'
        iclass = 'form-boolean'
        ihint = 'Filter for open items. Use true or false.'
      when :flag
        ilabel = 'Flag'
        iclass = 'form-boolean'
        ihint = 'Filter for flagged tasks. Use true or false.'
      when :template
        ilabel = 'Template'
        iclass = 'form-boolean'
        ihint = 'Filter for template cases. Use true or false.'
      when :stat
        ilabel = 'Stat'
        iclass = 'form-boolean'
        ihint = 'Filter for stats by name. Use true or false.'
      else
        raise NotImplementedError, sym.to_s
      end

      case pr
      when :string
        itype = 'text'
        ivalue = query[sym] || ''
      when :boolean
        itype = 'text'
        if query[sym].nil?
          ivalue = ''
        else
          ivalue = query[sym] ? 'true' : 'false'
        end
      when :integer
        itype = 'text'
        ivalue = query[sym] ? query[sym].to_s : ''
      when :time
        itype = 'text'
        ivalue = query[sym] ? ICFS.time_local(query[sym], cfg) :  ''
      else
        raise NotImplementedError, pr.to_s
      end

      FormQueryItem % [ilabel, txt, iclass, itype, ivalue, ihint]
    end

    # display the form
    formClass = disp ? '' : ' hidden'

    return FormQuery % [
      formClass,
      act,
      inputs.join('')
    ]
  end # def _form_query


  # Query Form
  FormQuery = '
  <div class="form%s" id="que-form"><form method="get" action="%s">%s
    <input class="submit" type="submit" value="Search">
  </form></div>'


  # Query form item
  FormQueryItem = '
    <div class="form-row">
      <div class="list-label">%s:</div>
      <input name="%s" class="%s" type="%s" value="%s">
      <div class="tip"><div class="tip-disp"></div><div class="tip-info">
        %s
      </div></div>
    </div>'


  ###############################################
  # Case form
  def _form_case(env, cse)

    status = ' checked' if cse['status']

    # tags
    tags_cnt = 0
    if cse['tags'][0] != ICFS::TagNone
      tags_list = cse['tags'].map do |tg|
        tags_cnt = tags_cnt + 1
        FormCaseTag % [ tags_cnt, Rack::Utils.escape_html(tg) ]
      end
      tags = tags_list.join('')
    else
      tags = ''
    end

    # stats
    stats_cnt = 0
    if cse['stats']
      stats_list = cse['stats'].map do |st|
        stats_cnt += 1
        FormCaseStat % [stats_cnt, Rack::Utils.escape_html(st)]
      end
      stats = stats_list.join('')
    else
      stats = ''
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
        grants.join(''),
      ]
    end

    return FormCase % [
        Rack::Utils.escape_html(cse['title']),
        status,
        tags_cnt, tags,
        acc_cnt, acc_list.join(''),
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
    </div>'


  # Case form Tag each
  FormCaseTag = '
        <div>
          <input class="form-tag" type="text" name="cse-tag-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'


  # Case form Stat each
  FormCaseStat = '
        <div>
          <input class="form-stat" type="text" name="cse-stat-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'


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
          </div>'

  # Case form Grant each
  FormCaseGrant = '
              <div>
                <input class="form-usergrp" type="text" name="cse-acc-%d-%d"
                  value="%s">
              </div>'


  #############################################
  # New entry form
  #
  # @param env [Hash] Rack enviornment
  # @param cid [String] caseid
  # @param ent [Hash] the Entry
  # @param opts [Hash] options
  #
  #
  def _form_entry(env, cid, ent=nil, opts={})
    api = env['icfs']

    # title
    if ent && ent['title']
      title = Rack::Utils.escape_html(ent['title'])
    else
      title = ''
    end

    # time
    if ent && ent['time']
      time = ICFS.time_local(ent['time'], api.config)
    else
      time = ''
    end

    # action
    if opts[:action]
      anum = opts[:action]
    elsif ent && ent['action']
      anum = ent['action']
    else
      anum = 0
    end

    # content
    if ent && ent['content']
      content = Rack::Utils.escape_html(ent['content'])
    else
      content = ''
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
      files = files_list.join("\n")
    else
      files = ''
    end

    # tags
    tags_cnt = 0
    if ent && ent['tags'][0] != ICFS::TagNone
      tags_list = ent['tags'].map do |tg|
        tags_cnt = tags_cnt + 1
        FormEntryTagEach % [tags_cnt, Rack::Utils.escape_html(tg)]
      end
      tags = tags_list.join('')
    else
      tags = ''
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
      index = idx_list.join('')
    else
      index = ''
    end

    # stats select
    stats_sel = api.stats_list(cid).to_a.sort.map do |stat|
      esc = Rack::Utils.escape_html(stat)
      FormEntryStatOpt % [esc, esc]
    end
    stats_sel = FormEntryStatSel % stats_sel.join('')

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
          claims.join('')
        ]
      end
      stats = stats_list.join('')
    else
      stats = ''
    end

    # perms select
    al = env['icfs'].access_list(cid)
    perms_sel = al.sort.map do |pm|
      esc = Rack::Utils.escape_html(pm)
      FormEntryPermOpt % [esc, esc]
    end
    perms_sel = perms_sel.join('')

    # perms count & list
    perms_cnt = 0
    if ent && ent['perms']
      perms_list = ent['perms'].map do |pm|
        perms_cnt = perms_cnt + 1
        esc = Rack::Utils.escape_html(pm)
        FormEntryPermEach % [esc, perms_cnt, esc]
      end
      perms = perms_list.join('')
    else
      perms = ''
    end

    return FormEntry % [
        opts[:enable] ? 'true' : 'false',
        ent ? ent['entry'] : 0,
        anum,
        opts[:enable] ? '' : FormEntryEnable,
        opts[:enable] ? '' : ' hidden',
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


  # entry toggle button
  FormEntryEnable = '
      <div class="sect-right">
        <button id="ent-ena-button" class="ent-ena" type="button"
          onclick="entEnable()">Toggle Edit
        </button>
      </div>'.freeze


  # entry edit form
  FormEntry = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Entry</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Describe the activity.
        </div></div>
        <div class="sect-fill"> </div>
        <input id="ent-ena" name="ent-ena" type="hidden" value="%s">
        <input name="ent-num" type="hidden" value="%d">
        <input name="ent-act" type="hidden" value="%d">%s
      </div>
    </div>
    <div id="ent-body" class="ent-body%s">

    <div class="sect">
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
    </div>
    </div>'


  # Entry form tag each
  FormEntryTagEach = '
        <div>
          <input class="form-tag" type="text" name="ent-tag-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'


  # Entry form index each
  FormEntryIndexEach = '
        <div>
          <input type="hidden" name="ent-idx-%d" value="%d">%s
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'


  # Entry form Perm each
  FormEntryPermEach = '
        <div>%s
          <input type="hidden" name="ent-perm-%d" value="%s">
          <button class="form-del" type="button" onclick="delDiv(this)">X
          </button>
        </div>'


  # Entry form Perm option
  FormEntryPermOpt = '
        <option value="%s">%s</option>'


  # Entry form file each
  FormEntryFileEach = '
    <div>
      <input class="form-file-name" type="text" name="ent-file-%d-name"
        value="%s">
      <input class="form-file-upl" type="file" name="ent-file-%d-file">
      <input type="hidden" name="ent-file-%d-num" value="%d-%d">
      <button class="form-del" type="button" onclick="delDiv(this)">X
      </button>
    </div>'


  # Entry form Stat option
  FormEntryStatOpt = '
            <option value="%s">%s</option>'


  # Entry form Stat select
  FormEntryStatSel = '
          <select class="stat-sel" id="ent-stat-sel" name="ent-stat-sel">%s
          </select>'


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
        </div>'


  # Entry form Stat Claim
  FormEntryClaim = '
            <div>
              <input class="form-usergrp" type="text" name="ent-stat-%d-%d"
                value="%s">
            </div>'


  ###############################################
  # Action form
  #
  def _form_action(env, cid, act = nil)
    api = env['icfs']
    cfg = api.config

    # new action
    if !act
      ta = [{
        'assigned' => ICFS::UserCase,
        'title' => '',
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
      raise(Error::Perms, 'Missing perm: %s' % ICFS::PermAction)
    end

    # get user/group list
    ur = Set.new
    ur.add api.user
    ur.merge api.roles

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
          ix, tk['status'] ? ' checked' : '' ]
        flag = FormActionFlagEd % [
          ix, tk['flag'] ? ' checked' : '' ]
        if tk['time']
          time = FormActionTimeEd % [ ix, ICFS.time_local(tk['time'], cfg) ]
        else
          time = FormActionTimeEd % [ix, '']
        end

        if tk['tags'][0] == ICFS::TagNone
          tags_cnt = 1
          tags = FormActionTagEd % [ix, 1, '']
        else
          tags_cnt = 0
          tags = tk['tags'].map do |tg|
            tags_cnt = tags_cnt + 1
            FormActionTagEd % [
              ix, tags_cnt, Rack::Utils.escape_html(tg) ]
          end
          tags = tags.join('')
        end

        tag_list = 'act-%d-tag-list' % ix
        tag_add = FormActionTagButton % tag_list

      # can't edit
      else
        esc = Rack::Utils.escape_html(tk['title'])
        title = FormActionTitleRo % [ ix, esc, esc ]
        status = FormActionStatusRo % [ ix,
          tk['status'] ? 'true' : 'false',
          tk['status'] ? 'Open' : 'Closed',
        ]
        if tk['flag']
          flag = FormActionFlagRo % ix
        else
          flag = FormActionFlagEd % [ ix, '' ]
        end
        esc = ICFS.time_local(tk['time'], cfg)
        time = FormActionTimeRo % [ ix, esc, esc ]

        tags_cnt = 0
        if tk['tags'][0] != ICFS::TagNone
          tags = tk['tags'].map do |tg|
            tags_cnt = tags_cnt + 1
            esc = Rack::Utils.escape_html(tg)
            FormActionTagRo % [ ix, tags_cnt, esc, esc ]
          end
          tags = tags.join('')
        else
          tags = ''
        end

        tag_add = ''

      end

      tasks << FormActionTask % [
        edit ? 'ed' : 'ro',
        ug, title, status, flag, time, ix, ix, tags_cnt, tags, tag_add
      ]
    end

    return FormAction % [
        act ? act['action'] : 0,
        tasks.size,
        act ? act['action'] : 0,
        tasks.join('')
      ]
  end # def _form_action()


  # action edit form
  FormAction = '
    <div class="sect" id="act_section">
      <div class="sect-main">
        <div class="sect-label">Action</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          A unit of work, accomplished in a set of related real-world
          and administrative activities.
        </div></div>
        <div class="sect-fill"> </div>
        <input name="act-num" type="hidden" value="%d">
        <div id="act-task-add" class="sect-right">
          <button class="tsk-add" type="button" onclick="actAddTask()">+
          </button>
        </div>
        <input id="act-cnt" name="act-cnt" type="hidden" value="%d">
        <input type="hidden" name="act-num" value="%d">
      </div>
      <div id="act-tasks">%s
      </div>
    </div>'


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
        </div>'


  # action tasked editable
  FormActionTaskedEd = '
            <input class="form-usergrp" name="act-%d-task" type="text"
              value="%s">'


  # action tasked read only
  FormActionTaskedRo = '
            <input name="act-%d-task" type="hidden" value="%s">
            <div class="list-usergrp">%s</div>'


  # action title editable
  FormActionTitleEd = '
            <input class="form-title" name="act-%d-title" type="text"
              value="%s">'


  # action title read only
  FormActionTitleRo = '
            <input name="act-%d-title" type="hidden" value="%s">
            <div class="list-title">%s</div>'


  # action open editable
  FormActionStatusEd = '
            <input class="form-check" name="act-%d-status" type="checkbox"
              value="true"%s>'

  # action open readonly
  FormActionStatusRo = '
            <input name="act-%d-status" type="hidden" value="%s">
            <div class="item-boolean">%s</div>'


  # action flag editable
  FormActionFlagEd = '
            <input class="form-check" name="act-%d-flag" type="checkbox"
              value="true"%s>'


  # action flag read-only
  FormActionFlagRo = '
            <input name="act-%d-flag" type="hidden" value="true">
            <div class="item-boolean">flagged</div>'


  # action time editable
  FormActionTimeEd = '
            <input class="form-time" name="act-%d-time" type="text"
              value="%s">'


  # action time read-only
  FormActionTimeRo = '
            <input name="act-%d-time" type="hidden" value="%s">
            <div class="item-time">%s</div>'


  # action tag editable
  FormActionTagEd = '
              <div>
                <input class="form-tag" type="text" name="act-%d-tag-%d"
                  value="%s"><button class="form-del" type="button"
                  onclick="delDiv(this)">X</button>
              </div>'


  # action tag read-only
  FormActionTagRo = '
              <div>
                <input type="hidden" name="act-%d-tag-%d" value="%s">%s
              </div>'


  # action tag button
  FormActionTagButton = '
            <button class="tag-add" type="button"
              onClick="addTag(&quot;%s&quot;)">+</button>'


  ###############################################
  # Index form
  def _form_index(env, cid, idx=nil)

    # title
    if idx && idx['title']
      title = Rack::Utils.escape_html(idx['title'])
    else
      title = ''
    end

    # content
    if idx && idx['content']
      content = Rack::Utils.escape_html(idx['content'])
    else
      content = ''
    end

    # tags
    tags_cnt = 0
    if idx && idx['tags'][0] != ICFS::TagNone
      tags_list = idx['tags'].map do |tg|
        tags_cnt += 1
        FormIndexTagEach % [tags_cnt, Rack::Utils.escape_html(tg)]
      end
      tags = tags_list.join('')
    else
      tags = ''
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
    </div> '


  # Index form tag
  FormIndexTagEach = '
          <div>
            <input class="form-tag" type="text" name="idx-tag-%d" value="%s">
          </div>'


  ###############################################
  # Config Form
  #
  def _form_config(env)
    cfg = env['icfs'].config
    tz = cfg.get('tz')
    rel_time = cfg.get('rel_time') ? 'true' : 'false'
    return FormConfig % [tz, rel_time]
  end # def _form_config()


  # Config form
  FormConfig = '
    <div class="sect">
      <div class="sect-main">
        <div class="sect-label">Config</div>
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Configuration settings.
        </div></div>
        <div class="sect-fill"> </div>
      </div>
      <div class="form-row">
        <div class="list-label">Timezone:</div>
        <input class="form-tz" name="cfg-tz" type="text" value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Timezone to display date/times, format as +/-HH:MM.
        </div></div>
      </div>
      <div class="form-row">
        <div class="list-label">Rel. Time:</div>
        <input class="form-boolean" name="cfg-reltime" type="text" value="%s">
        <div class="tip"><div class="tip-disp"></div><div class="tip-info">
          Display relative times e.g. 3 days ago.
        </div></div>
      </div>
    </div>'


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
    cse['status'] = (para['cse-status'] == 'true') ? true : false

    # tags
    tags = []
    tcnt = para['cse-tag'].to_i
    if tcnt > 100
      raise(Error::Interface, 'Tag count too large')
    end
    tcnt.times do |ix|
      tx = 'cse-tag-%d' % [ix + 1]
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
      raise(Error::Interface, 'Access count too large')
    end
    acnt.times do |ix|
      ixr = ix + 1

      pnam = para['cse-acc-%d-perm' % ixr]
      gcnt = para['cse-acc-%d' % ixr].to_i
      next if gcnt == 0 || !pnam || pnam.empty?

      grant = []
      if gcnt > 100
        raise(Error::Interface, 'Grant count too large')
      end
      gcnt.times do |gx|
        sug = para['cse-acc-%d-%d' % [ixr, gx+1]]
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
    return nil unless para['ent-ena'] == 'true'

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
    raise(Error::Interface, 'too many tags') if(tcnt > 100)
    tcnt.times do |ix|
      tx = 'ent-tag-%d' % [ix + 1]
      tag = para[tx]
      tags << tag unless( !tag || tag.empty? )
    end
    ent['tags'] = tags.uniq.sort unless tags.empty?

    # indexes
    index = []
    icnt = para['ent-idx-cnt'].to_i
    raise(Error::Interface, 'Too many indexes') if(icnt > 100)
    icnt.times do |ix|
      tx = 'ent-idx-%d' % (ix + 1)
      xnum = para[tx].to_i
      index << xnum unless xnum == 0
    end
    ent['index'] = index.uniq.sort unless index.empty?

    # perms
    perms = []
    pcnt = para['ent-perm-cnt'].to_i
    raise(Error::Interface, 'Too many perms') if(pcnt > 100)
    pcnt.times do |ix|
      px = 'ent-perm-%d' % [ix + 1]
      pm = para[px]
      next if !pm || pm.empty?
      perms << pm
    end
    ent['perms'] = perms unless perms.empty?

    # stats
    stats = []
    scnt = para['ent-stats-cnt'].to_i
    raise(Error::Interface, 'Too many stats') if(scnt > 100)
    scnt.times do |ix|
      ixr = ix + 1
      sname = para['ent-stat-%d-name' % ixr]
      sval = para['ent-stat-%d-value' % ixr]
      next if !sname || !sval || sname.empty? || sval.empty?

      sval = sval.to_f

      scred = para['ent-stat-%d' % ixr].to_i
      sugs = []
      raise(Error::Interface, 'Too many credits') if(scred > 100)
      scred.times do |cx|
        sug = para['ent-stat-%d-%d' % [ixr, cx + 1]]
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
    raise(Error::Interface, 'Too many files') if(fcnt > 100)
    fcnt.times do |ix|
      ixr = ix + 1
      fnam = para['ent-file-%d-name' % ixr]
      fupl = para['ent-file-%d-file' % ixr]
      fnum = para['ent-file-%d-num' % ixr]

      if fnum
        fnum, flog = fnum.split('-').map do |xx|
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
    act = {}

    # action
    anum = para['act-num'].to_i
    act['action'] = anum if anum != 0

    # tasks
    tasks = []
    acnt = para['act-cnt'].to_i
    raise(Error::Interface, 'Too many tasks') if(acnt > 100)
    acnt.times do |ix|
      tx = 'act-%d' % [ix + 1]

      ug = para[tx + '-task']
      next if ug.nil? || ug.empty?
      title = para[tx + '-title']
      status = (para[tx + '-status'] == 'true') ? true : false
      flag = (para[tx + '-flag'] == 'true') ? true : false

      tstr = para[tx + '-time']
      time = _util_time_parse(env, tstr)

      tags = []
      tcnt = para[tx + '-tag'].to_i
      raise(Error::Interface, 'Too many tags') if (tcnt > 100)
      tcnt.times do |gx|
        tag = para[tx + '-tag-%d' % [gx + 1]]
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
    raise(Error::Interface, 'Too many tags') if(tcnt > 100)
    tcnt.times do |ix|
      tx = 'idx-tag-%d' % [ix + 1]
      tag = para[tx]
      tags << tag unless( !tag | tag.empty? )
    end
    idx['tags'] = tags.uniq.sort unless tags.empty?

    return idx
  end # def _post_index()


  ###############################################
  # Config edit
  #
  def _post_config(env, para)
    cfg = {
      'tz' => para['cfg-tz'],
      'rel_time' => (para['cfg-reltime'].downcase == 'true' ? true : false),
    }
    return cfg
  end # def _post_config()


###########################################################
# Links
###########################################################

  ###############################################
  # Link to info page
  #
  def _a_info(env, txt)
    '<a href="%s/info">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Case search
  def _a_case_search(env, query, txt)
    '<a href="%s/case_search%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Entry search
  #
  def _a_entry_search(env, query, txt)
    '<a href="%s/entry_search%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Log search
  #
  def _a_log_search(env, query, txt)
    '<a href="%s/log_search%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Action search
  #
  def _a_action_search(env, query, txt)
    '<a href="%s/action_search%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Index search
  #
  def _a_index_search(env, query, txt)
    '<a href="%s/index_search%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to stats search
  #
  def _a_stats(env, query, txt)
    '<a href="%s/stats%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to case tags
  def _a_case_tags(env, query, txt)
    '<a href="%s/case_tags%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to entry tags
  #
  def _a_entry_tags(env, query, txt)
    '<a href="%s/entry_tags/%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt),
    ]
  end # def _a_entry_tags()


  ###############################################
  # Link to action tags
  def _a_action_tags(env, query, txt)
    '<a href="%s/action_tags%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end # def _a_action_tags()


  ###############################################
  # Link to action tags
  def _a_index_tags(env, query, txt)
    '<a href="%s/index_tags/%s">%s</a>' % [
      env['SCRIPT_NAME'],
      _util_query(query),
      Rack::Utils.escape_html(txt)
    ]
  end # def _a_index_tags()


  ###############################################
  # Link to create a case
  #
  def _a_case_create(env, tid, txt)
    '<a href="%s/case_create/%s">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(tid),
      Rack::Utils.escape_html(txt),
    ]
  end


  ###############################################
  # Link to Case edit
  #
  def _a_case_edit(env, cid, txt)
    '<a href="%s/case_edit/%s">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Entry edit
  #
  def _a_entry_edit(env, cid, enum, anum, txt)
    '<a href="%s/entry_edit/%s/%d/%d">%s</a>' % [
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
    '<a href="%s/index_edit/%s/%d">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      xnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Action edit
  #
  def _a_action_edit(env, cid, anum, txt)
    '<a href="%s/action_edit/%s/%d">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      anum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Config edit
  #
  def _a_config_edit(env, txt)
    '<a href="%s/config_edit">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Home
  #
  def _a_home(env, txt)
    '<a href="%s/home">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to Case
  #
  def _a_case(env, cid, lnum, txt)
    '<a href="%s/case/%s/%d">%s</a>' % [
      env['SCRIPT_NAME'],
      Rack::Utils.escape(cid),
      lnum,
      Rack::Utils.escape_html(txt)
    ]
  end


  ###############################################
  # Link to an entry
  def _a_entry(env, cid, enum, lnum, txt)
    '<a href="%s/entry/%s/%d/%d">%s</a>' % [
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
    '<a href="%s/log/%s/%d">%s</a>' % [
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
    '<a href="%s/action/%s/%d/%d">%s</a>' % [
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
    '<a href="%s/index/%s/%d/%d">%s</a>' % [
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
    '<a href="%s/file/%s/%d-%d-%d-%s">%s</a>' % [
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
    if env['REQUEST_METHOD'] != 'GET'
      raise(Error::Interface, 'Only GET method allowed')
    end
  end # def _verb_get()


  ###############################################
  # Require a GET or POST method
  #
  def _verb_getpost(env)
    if env['REQUEST_METHOD'] != 'GET' &&
       env['REQUEST_METHOD'] != 'POST'
      raise(Error::Interface, 'Only GET or POST method allowed')
    end
  end # def _verb_getpost()


  ###############################################
  # Process the POST
  #
  def _util_post(env)
    rck = Rack::Request.new(env)
    para = rck.POST
    para.each do |key, val|
      val.force_encoding('utf-8') if val.is_a?(String)
    end
    return para
  end # def _util_post()


  ###############################################
  # Get the case
  #
  def _util_case(env)
    cmps = env['icfs.cmps']
    if cmps.size < 2 || cmps[1].empty?
      raise(Error::NotFound, 'No case specified in the URL')
    end
    cid = Rack::Utils.unescape(cmps[1])
    Items.validate(cid, 'case', Items::FieldCaseid)
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
  # Parse a provided time string
  #
  def _util_time_parse(env, str)
    cfg = env['icfs'].config
    time = ICFS.time_parse(str, cfg)
    raise(Error::Value, 'Invalid time string') if !time
    return time
  end


  # Generate query string
  #
  def _util_query(query)
    if query
      qa = query.map do |key, val|
        '%s=%s' % [Rack::Utils.escape(key), Rack::Utils.escape(val)]
      end
      return '?' + qa.join('&amp;')
    else
      return ''
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
        query[sym] = val.split(',').map{|aa| aa.strip}
      when :boolean
        if val.downcase == 'true'
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
      'Content-Type' => 'text/html; charset=utf-8',
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
'


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
