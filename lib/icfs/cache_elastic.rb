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

require 'json'
require 'socket'
require_relative 'elastic'


module ICFS

##########################################################################
# Implements {ICFS::Cache Cache} using Elasticsearch
#
class CacheElastic < Cache

  include Elastic

  private

  ###############################################
  # The ES mappings for all of the indexes
  Maps = {
    :case => '{
  "mappings": { "_doc": { "properties": {
    "icfs": { "enabled": false },
    "caseid": { "type": "keyword" },
    "log": { "enabled": false },
    "entry": { "enabled": false },
    "template": { "type": "boolean" },
    "status": { "type": "boolean" },
    "title": { "type": "text" },
    "tags": { "type": "keyword" },
    "access": { "type": "nested", "properties": {
      "perm": { "type": "keyword" },
      "grant": { "type": "keyword" }
    }}}
  }}}
}',

    :log => '{
  "mappings": { "_doc": { "properties": {
    "icfs": { "enabled": false },
    "caseid": {"type": "keyword" },
    "log": { "type": "integer" },
    "prev": { "enabled": false },
    "time": { "type": "date", "format": "epoch_second" },
    "user": { "type": "keyword" },
    "entry": { "properties": {
      "num": { "type": "integer" },
      "hash": { "enabled": false }
    }},
    "index": { "properties": {
      "num": { "type": "integer" },
      "hash": { "enabled": false }
    }},
    "action": { "properties": {
      "num": { "type": "integer" },
      "hash": { "enabled": false }
    }},
    "case": { "properties": {
      "set": { "type": "boolean" },
      "hash": { "enabled": false }
    }},
    "files_hash": { "enabled": false }
  }}}
}',

    :entry => '{
  "mappings": { "_doc": { "properties": {
    "icfs": { "enabled": false },
    "caseid": { "type": "keyword" },
    "entry": { "type": "integer" },
    "log": { "enabled": false },
    "user": { "type": "keyword" },
    "time": { "type": "date", "format": "epoch_second" },
    "title": { "type": "text" },
    "content": { "type": "text" },
    "tags": { "type": "keyword" },
    "index": { "type": "integer" },
    "action": { "type": "integer" },
    "perms": { "type": "keyword" },
    "stats": { "type": "nested", "properties": {
      "name": { "type": "keyword" },
      "value": { "type": "double" },
      "credit": { "type": "keyword" }
    }},
    "files": { "properties": {
      "log": { "enabled": false },
      "num": { "enabled": false },
      "name": { "type": "text" }
    }}
  }}}
}',

    :action => '{
  "mappings": { "_doc": { "properties": {
    "icfs": { "enabled": false },
    "caseid": { "type": "keyword" },
    "action": { "type": "integer" },
    "log": { "enabled": false },
    "entry": { "enabled": false },
    "tasks": { "type": "nested","properties": {
      "assigned": { "type": "keyword" },
      "title": { "type": "text" },
      "status": { "type": "boolean" },
      "flag": { "type": "boolean" },
      "time": { "type": "date", "format": "epoch_second" },
      "tags": { "type": "keyword" }
    }}
  }}}
}',

    :index => '{
  "mappings": { "_doc": { "properties": {
    "icfs": { "enabled": false },
    "caseid": { "type": "keyword" },
    "index": { "type": "integer" },
    "log": { "enabled": false },
    "entry": { "enabled": false },
    "title": {
      "type": "text",
      "fields": { "raw": { "type": "keyword" }}
    },
    "content": { "type": "text" },
    "tags": { "type": "keyword" }
  }}}
}',

    :current => '{
  "mappings": {"_doc": {
    "enabled": false
  }}
}',

    :lock => '{
  "mappings": { "_doc": {
    "enabled": false
  }}
}',
  }.freeze


  public


  ###############################################
  # New instance
  #
  # @param map [Hash] Symbol to String of the indexes.  Must provide
  #   :case, :log, :entry, :action, :current, and :lock
  # @param es [Faraday] Faraday instance to the Elasticsearch cluster
  #
  def initialize(map, es)
    @map = map
    @es = es
    @name = '%s:%d' % [Socket.gethostname, Process.pid]
    @name.freeze
  end


  ###############################################
  # (see Cache#supports)
  #
  #def supports; raise NotImplementedError; end


  ###############################################
  # (see Cache#lock_take)
  #
  def lock_take(cid)

    json = '{"client":"%s"}' % @name
    url = '%s/_doc/%s/_create' % [@map[:lock], CGI.escape(cid)]
    head = {'Content-Type' => 'application/json'}.freeze

    # try to take
    tries = 5
    while tries > 0
      resp = @es.run_request(:put, url, json, head)
      return true if resp.success?
      tries = tries - 1
      sleep(0.1)
    end

    # failed to take lock
    raise('Elasticsearch lock take failed: %s' % cid)
  end


  ###############################################
  # (see Cache#lock_release)
  #
  def lock_release(cid)
    url = '%s/_doc/%s' % [@map[:lock], CGI.escape(cid)]
    resp = @es.run_request(:delete, url, '', {})
    if !resp.success?
      raise('Elasticsearch lock release failed: %s' % cid)
    end
  end


  ###############################################
  # (see Cache#current_read)
  #
  def current_read(cid)
    _read(:current, cid)
  end


  ###############################################
  # (see Cache#current_write)
  #
  def current_write(cid, item)
    _write(:current, cid, item)
  end


  ###############################################
  # (see Cache#case_read)
  #
  def case_read(cid)
    _read(:case, cid)
  end


  ###############################################
  # (see Cache#case_write)
  #
  def case_write(cid, item)
    _write(:case, cid, item)
  end


  ###############################################
  # match query
  #
  def _query_match(field, val)
    return nil if !val
    { 'match' => { field => { 'query' => val } } }
  end # def _query_match()


  ###############################################
  # match all query
  #
  def _query_all()
    { 'match_all' => {} }
  end # def _query_all()


  ###############################################
  # (see Cache#case_search)
  #
  def case_search(query)

    # build the query
    must = [
      _query_match('title', query[:title]),
    ].compact
    filter = [
      _query_term('tags', query[:tags]),
      _query_term('status', query[:status]),
      _query_term('template', query[:template]),
    ].compact
    access = [
      _query_term('access.grant', query[:grantee]),
      _query_term('access.perm', query[:perm]),
    ].compact
    unless access.empty?
      qu = (access.size == 1) ? access[0] : _query_bool(nil, access, nil, nil)
      filter << _query_nested('access', qu)
    end
    req = { 'query' => _query_bool(must, filter, nil, nil) }

    # highlight
    hl = {}
    hl['title'] = {} if query[:title]
    req['highlight'] = { 'fields' => hl } unless hl.empty?

    # sort
    unless query[:title]
      req['sort'] = { 'caseid' => 'asc' }
    end

    # paging
    _page(query, req)

    # run the search
    url = @map[:case] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    return _results(resp, query, ResultsCase)
  end # def case_search


  # the Case results fields
  ResultsCase = {
    caseid: 'caseid',
    template: 'template',
    status: 'status',
    title: 'title',
    tags: 'tags',
  }.freeze


  ###############################################
  # Process search results
  #
  # @param resp [Hash] the response from Elasticsearch
  # @param query [Hash] the original request
  # @param fields [Hash] Fields to return
  # @yield [src] The source object
  # @yieldreturn [Hash] the search result object
  #
  def _results(resp, query, fields=nil)

    # size defaults to 25
    size = query[:size] ? query[:size].to_i : 0
    size = DefaultSize if size == 0

    rh = JSON.parse(resp.body)
    results = {
      query: query,
      hits: rh['hits']['total'],
      size: size,
    }

    # process each result
    results[:list] = rh['hits']['hits'].map do |hh|

      src = hh['_source']
      hl = hh['highlight']

      if hl
        snip = String.new
        hl.each{|fn, ary| ary.each{|ht| snip << ht}}
      else
        snip = nil
      end

      # fields provided
      if fields
        obj = {}
        fields.each do |aa, bb|
          if bb.is_a?(Array)
            case bb[1]

            # a sub value
            when :sub
              val = src[bb[0]]
              obj[aa] = val.nil? ? 0 : val[bb[2]]

            # size of a value
            when :size
              val = src[bb[0]]
              obj[aa] = val.nil? ? 0 : val.size

            # zero for nil
            when :zero
              val = src[bb[0]]
              obj[aa] = val.nil? ? 0 : val

            # empty array for nil
            when :empty
              val = src[bb[0]]
              obj[aa] = val.nil? ? [] : val

            else
              raise(ArgumentError, 'Not a valid field option')
            end
          else
            obj[aa] = src[bb]
          end
        end

      # pass the source to the block to generate the search object
      else
        obj = yield src
      end

      # and provide each result
      {
        score: hh['_score'],
        snippet: snip,
        object: obj,
      }
    end

    return results
  end # def _results()
  private :_results


  # default page size
  DefaultSize = 25


  ###############################################
  # Do paging
  #
  # @param query [Hash] the query
  # @param req [Hash] the constructed ES request
  #
  def _page(query, req)

    # size defaults
    size = query[:size] ? query[:size].to_i : 0
    size = DefaultSize if size == 0

    # page defaults to 1
    page = query[:page] ? query[:page].to_i : 0
    page = 1 if page == 0

    req['size'] = size
    req['from'] = (page - 1) * size

  end # def _page()
  private :_page



  ###############################################
  # (see Cache#entry_read)
  #
  def entry_read(cid, enum)
    _read(:entry, '%s.%d' % [cid, enum])
  end


  ###############################################
  # (see Cache#entry_write)
  #
  def entry_write(cid, enum, item)
    _write(:entry, '%s.%d' % [cid, enum], item)
  end


  ###############################################
  # Nested query
  #
  def _query_nested(field, query)
    {
      'nested' => {
        'path' => field,
        'query' => query
      }
    }
  end # def _query_nested()


  ###############################################
  # (see Cache#entry_search)
  #
  def entry_search(query)

    # build the query
    must = [
      _query_match('title', query[:title]),
      _query_match('content', query[:content]),
    ].compact
    filter = [
      _query_term('tags', query[:tags]),
      _query_term('caseid', query[:caseid]),
      _query_times('time', query[:after], query[:before]),
      _query_term('action', query[:action]),
      _query_term('index', query[:index]),
    ].compact
    stats = [
      _query_term('stats.name', query[:stat]),
      _query_term('stats.credit', query[:credit]),
    ].compact
    unless stats.empty?
      qu = (stats.size == 1) ? stats[0] : _query_bool(nil, stats, nil, nil)
      filter << _query_nested('stats', qu)
    end
    req = { 'query' => _query_bool(must, filter, nil, nil) }

    # highlight
    hl = {}
    hl['title'] = {} if query[:title]
    hl['content'] = {} if query[:content]
    req['highlight'] = { 'fields' => hl } unless hl.empty?

    # sort
    case query[:sort]
    when 'time_desc'
      req['sort'] = [
        { 'time' => 'desc' },
        { '_id' => 'desc' },
      ]
    when 'time_asc'
      req['sort'] = [
        { 'time' => 'asc' },
        { '_id' => 'desc' },
      ]
    when nil
      if !query[:title] && !query[:content]
       req['sort'] = [
          { 'time' => 'desc' },
          { '_id' => 'desc' },
        ]
      end
    end

    # paging
    _page(query, req)

    # run the search
    url = @map[:entry] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    return _results(resp, query, ResultsEntry)
  end # def entry_search()


  # Entry search results fields
  ResultsEntry = {
    caseid: 'caseid',
    entry: 'entry',
    time: 'time',
    title: 'title',
    tags: 'tags',
    perms: ['perms', :empty],
    action: ['action', :zero],
    indexes: ['index', :size],
    files: ['files', :size],
    stats: ['stats', :size],
  }.freeze



  ###############################################
  # (see Cache#action_read)
  #
  def action_read(cid, anum)
    _read(:action, '%s.%d' % [cid, anum])
  end


  ###############################################
  # (see Cache#action_write)
  #
  def action_write(cid, anum, item)
    _write(:action, '%s.%d' % [cid, anum], item)
  end


  ###############################################
  # (see Cache#action_search)
  #
  def action_search(query)

    # build the query
    task_must = [
      _query_match('tasks.title', query[:title])
    ].compact
    task_filter = [
      _query_term('tasks.assigned', query[:assigned]),
      _query_term('tasks.status', query[:status]),
      _query_term('tasks.flag', query[:flag]),
      _query_times('tasks.time', query[:after], query[:before]),
      _query_term('tasks.tags', query[:tags]),
    ].compact
    must = [
      _query_nested(
        'tasks',
        _query_bool(task_must, task_filter, nil, nil)
      )
    ]
    filter = [
      _query_term('caseid', query[:caseid])
    ].compact
    req = { 'query' => _query_bool(must, filter, nil, nil) }

    # sort
    case query[:sort]
    when 'time_desc'
      srt = 'desc'
    when 'time_asc'
      srt = 'asc'
    else
      srt = query[:title] ? nil : 'desc'
    end
    if srt
      req['sort'] = [
        {
          'tasks.time' => {
            'order' => srt,
            'nested' => {
              'path' => 'tasks',
              'filter' => _query_term(
                'tasks.assigned', query[:assigned])
            }
          }
        },
        { '_id' => { 'order' => 'desc' } }
      ]
    end

    # paging
    _page(query, req)

    # run the search
    url = @map[:action] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    return _results(resp, query) do |src|
      tsk = src['tasks'].select{|tk| tk['assigned'] == query[:assigned]}.first
      {
        caseid: src['caseid'],
        action: src['action'],
        status: tsk['status'],
        flag: tsk['flag'],
        title: tsk['title'],
        time: tsk['time'],
        tags: tsk['tags'],
      }
    end
  end # def action_search()


  ###############################################
  # (see Cache#index_write)
  #
  def index_write(cid, xnum, item)
    _write(:index, '%s.%d' % [cid, xnum], item)
  end


  ###############################################
  # (see Cache#index_read)
  #
  def index_read(cid, xnum)
    _read(:index, '%s.%d' % [cid, xnum])
  end


  # (see Cache#index_search)
  #
  def index_search(query)

    # build the query
    must = [
      _query_match('title', query[:title]),
      _query_match('content', query[:content]),
    ].compact
    filter = [
      _query_term('caseid', query[:caseid]),
      _query_term('tags', query[:tags]),
      _query_prefix('title.raw', query[:prefix]),
    ].compact
    req = { 'query' => _query_bool(must, filter, nil, nil) }

    # highlight
    hl = {}
    hl['title'] = {} if query[:title]
    hl['content'] = {} if query[:content]
    req['highlight'] = { 'fields' => hl } unless hl.empty?

    # sort
    case query[:sort]
    when 'index_asc'
      req['sort'] = [
        { 'index' => 'asc' },
        { '_id' => 'desc' },
      ]
    when 'index_desc'
      req['sort'] = [
        { 'index' => 'desc' },
        { '_id' => 'desc' },
      ]
    when 'title_desc'
      req['sort'] = [
        { 'title.raw' => 'desc' },
        { '_id' => 'desc' },
      ]
    when 'title_asc'
      req['sort'] = [
        { 'title.raw' => 'asc' },
        { '_id' => 'desc' },
      ]
    else
      # default if not a title/content query
      if must.empty?
        req['sort'] = [
          { 'title.raw' => 'asc' },
          { '_id' => 'desc' },
        ]
      end
    end

    # paging
    _page(query, req)

    # run the search
    url = @map[:index] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    return _results(resp, query, ResultsIndex)
  end # end index_search()


  # Index search results fields
  ResultsIndex = {
    caseid: 'caseid',
    index: 'index',
    title: 'title',
    tags: 'tags',
  }.freeze


  ###############################################
  # (see Cache#index_tags)
  #
  def index_tags(query)

    # build the query
    ag = _agg_terms('tags', 'tags', nil)
    qu = _query_term('caseid', query[:caseid])
    qu = _query_constant(qu)
    req = {
      'query' => qu,
      'aggs' => ag,
      'size' => 0
    }

    # run the search
    url = @map[:index] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    # extract tags
    rh = JSON.parse(resp.body)
    rh = rh['aggregations']['tags']['buckets']
    list = rh.map do |hh|
      {
        object: {
          caseid: query[:caseid],
          tag: hh['key'],
          count: hh['doc_count'],
        }
      }
    end

    return {
      query: query,
      list: list.sort{|aa, bb| aa[:object][:tag] <=> bb[:object][:tag]}
    }
  end # def index_tags()


  ###############################################
  # (see Cache#log_read)
  #
  def log_read(cid, lnum)
    _read(:log, '%s.%d' % [cid, lnum])
  end


  ###############################################
  # (see Cache#log_write)
  #
  def log_write(cid, lnum, item)
    _write(:log, '%s.%d' % [cid, lnum], item)
  end


  # Log search results fields
  ResultsLog = {
    caseid: 'caseid',
    log: 'log',
    time: 'time',
    user: 'user',
    entry: ['entry', :sub, 'num'].freeze,
    index: ['index', :sub, 'num'].freeze,
    action: ['action', :sub, 'num'].freeze,
    case: ['case', :sub, 'set'].freeze,
    files: ['files_hash', :size].freeze,
  }.freeze


  ###############################################
  # (see Cache#log_search)
  #
  def log_search(query)

    # build the query
    filter = [
      _query_term('caseid', query[:caseid]),
      _query_times('time', query[:after], query[:before]),
      _query_term('user', query[:user]),
      _query_exists('case.set', query[:case_edit]),
      _query_term('entry.num', query[:entry]),
      _query_term('index.num', query[:index]),
      _query_term('action.num', query[:action]),
    ].compact
    req = { 'query' => _query_bool(nil, filter, nil, nil) }

    # sort
    case query[:sort]
    when 'time_desc', nil
      req['sort'] = [
        { 'time' => 'desc' },
        { '_id' => 'desc' },
      ]
    when 'time_asc'
      req['sort'] = [
        { 'time' => 'asc' },
        { '_id' => 'desc' },
      ]
    end

    # paging
    _page(query, req)

    # run the search
    url = @map[:log] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    return _results(resp, query, ResultsLog)
  end # def log_search()


  ###############################################
  # stats metric aggregation
  #
  def _agg_stats(name, field)
    { name => { 'stats' => { 'field' => field } } }
  end # def _agg_stats()


  ###############################################
  # terms bucket aggregation
  #
  def _agg_terms(name, field, sub)
    ag = { name => { 'terms' => { 'field' => field } } }
    ag[name]['aggs'] = sub if sub
    return ag
  end # def _agg_terms()


  ###############################################
  # filter bucket aggregation
  #
  def _agg_filter(name, qu, sub)
    ag = { name => { 'filter' => qu } }
    ag[name]['aggs'] = sub if sub
    return ag
  end # def _agg_filter()


  ###############################################
  # nested bucket aggregation
  #
  def _agg_nested(name, field, sub)
    ag = { name => { 'nested' => { 'path' => field } } }
    ag[name]['aggs'] = sub if sub
    return ag
  end # def _agg_nested()


  ###############################################
  # Term query
  #
  def _query_term(field, val)
    return nil if val.nil?
    { 'term' => { field => val } }
  end # def _query_term()


  ###############################################
  # Exists query
  #
  def _query_exists(field, val)
    return nil if val.nil?
    { 'exists' => { 'field' => field } }
  end # def _query_exists()


  ###############################################
  # keyword query
  def _query_keyw(field, val)
    return nil if val.nil?
    if val.is_a?(Array)
      qu = { 'terms' => { field => val } }
    else
      qu = {'term' => { field => val } }
    end
    return qu
  end # def _query_keyw()


  ###############################################
  # times query
  def _query_times(field, val_gt, val_lt)
    return nil if( val_gt.nil? && val_lt.nil? )
    tq = {}
    tq['gt'] = val_gt if val_gt
    tq['lt'] = val_lt if val_lt
    return {'range' => { field => tq } }
  end # def _query_times()


  ###############################################
  # prefix string query
  def _query_prefix(field, val)
    return nil if val.nil?
    return { 'prefix' => { field => val } }
  end # def _query_prefix()


  ###############################################
  # bool query
  def _query_bool(must, filter, should, must_not)
    qu = {}
    qu['must'] = must if(must && !must.empty?)
    qu['filter'] = filter if(filter && !filter.empty?)
    qu['should'] = should if(should && !should.empty?)
    qu['must_not'] = must_not if(must_not && !must_not.empty?)
    if qu.empty?
      return { 'match_all' => {} }
    else
      return { 'bool' => qu }
    end
  end # def _query_bool()


  ###############################################
  # (see Cache#stats)
  #
  def stats(query)

    # aggs
    ag = _agg_stats('vals', 'stats.value')
    ag = _agg_terms('stats', 'stats.name', ag)
    if query[:credit]
      cd = _query_term('stats.credit', query[:credit])
      ag = _agg_filter('credit', cd, ag)
    end
    ag = _agg_nested('nested', 'stats', ag)

    # build the query
    filt = [
      _query_term('caseid', query[:caseid]),
      _query_times('time', query[:after], query[:before]),
    ].compact
    qu = _query_bool(nil, filt, nil, nil)

    # the request
    req = {
      'query' => qu,
      'aggs' => ag,
      'size' => 0,
    }

    # run the search
    url = @map[:entry] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    # extract stats
    rh = JSON.parse(resp.body)
    if query[:credit]
      rh = rh['aggregations']['nested']['credit']['stats']['buckets']
    else
      rh = rh['aggregations']['nested']['stats']['buckets']
    end
    list = rh.map do |hh|
      {
        object: {
          stat: hh['key'],
          sum: hh['vals']['sum'],
          count: hh['vals']['count'],
          min: hh['vals']['min'],
          max: hh['vals']['max'],
        }
      }
    end

    # return the results
    return {
      query: query,
      list: list
    }
  end # def stats()


  ###############################################
  # constant score
  #
  def _query_constant(filter)
    {'constant_score' => { 'filter' => filter } }
  end # def _query_constant()


  ###############################################
  # (see Cache#entry_tags)
  #
  def entry_tags(query)

    # build the query
    ag = _agg_terms('tags', 'tags', nil)
    qu = _query_term('caseid', query[:caseid])
    qu = _query_constant(qu)
    req = {
      'query' => qu,
      'aggs' => ag,
      'size' => 0
    }

    # run the search
    url = @map[:entry] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    # extract tags
    rh = JSON.parse(resp.body)
    rh = rh['aggregations']['tags']['buckets']
    list = rh.map do |hh|
      {
        object: {
          caseid: query[:caseid],
          tag: hh['key'],
          count: hh['doc_count'],
        }
      }
    end

    return {
      query: query,
      list: list.sort{|aa, bb| aa[:object][:tag] <=> bb[:object][:tag]}
    }
  end # def entry_tags()


  ###############################################
  # (see Cache#case_tags)
  #
  def case_tags(query)

    # build the query
    filter = [
      _query_term('status', query[:status]),
      _query_term('template', query[:template]),
    ].compact
    access = [
      _query_term('access.grant', query[:grantee]),
      _query_term('access.perm', query[:perm]),
    ].compact
    unless access.empty?
      qu = (access.size == 1) ? access[0] : _query_bool(nil, access, nil, nil)
      filter << _query_nested('access', qu)
    end
    qu = _query_bool(nil, filter, nil, nil)
    ag = _agg_terms('tags', 'tags', nil)
    req = {
      'query' => qu,
      'aggs' => ag,
      'size' => 0
    }

    # run the search
    url = @map[:case] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    # extract tags
    rh = JSON.parse(resp.body)
    rh = rh['aggregations']['tags']['buckets']
    list = rh.map do |hh|
      {
        object: {
          tag: hh['key'],
          count: hh['doc_count'],
        }
      }
    end

    return {
      query: query,
      list: list.sort{|aa, bb| aa[:object][:tag] <=> bb[:object][:tag] }
    }
  end # def case_tags()


  ###############################################
  # (see Cache#action_tags)
  #
  def action_tags(query)

    # build the query
    task_filter = [
      _query_term('tasks.assigned', query[:assigned]),
      _query_term('tasks.status', query[:status]),
      _query_term('tasks.flag', query[:flag]),
      _query_times('tasks.time', query[:after], query[:before]),
    ].compact
    qu_filt = _query_bool(nil, task_filter, nil, nil)
    ag = _agg_terms('tags', 'tasks.tags', nil)
    ag = _agg_filter('filt', qu_filt, ag)
    ag = _agg_nested('nest', 'tasks', ag)
    if query[:caseid]
      qu = _query_term('caseid', query[:caseid])
    else
      qu = _query_all()
    end
    req = {
      'query' => qu,
      'aggs' => ag,
      'size' => 0
    }

    # run the search
    url = @map[:action] + '/_search'
    body = JSON.generate(req)
    head = { 'Content-Type' => 'application/json' }
    resp = @es.run_request(:get, url, body, head)
    raise 'search failed' if !resp.success?

    # extract tags
    rh = JSON.parse(resp.body)
    rh = rh['aggregations']['nest']['filt']['tags']['buckets']
    list =  rh.map do |hh|
      {
        object: {
          tag: hh['key'],
          count: hh['doc_count'],
        }
      }
    end

    return {
      query: query,
      list: list.sort{|aa, bb| aa[:object][:tag] <=> bb[:object][:tag]}
    }
  end # def action_tags()


end # class ICFS::CacheElastic

end # module ICFS
