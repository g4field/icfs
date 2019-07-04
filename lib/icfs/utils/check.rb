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

#
module ICFS


##########################################################################
# Low level utilities for working directly with ICFS systems.
#
module Utils


##########################################################################
# Check a case for errors
#
class Check


  ###############################################
  # Instance
  #
  # @param store [Store] The store to check
  # @param log [Logger] Where to log
  #
  def initialize(store, log)
    @store = store
    @log = log
  end


  ###############################################
  # check an object
  #
  def _item(title, read, read_args, hist, hash, val, con)

    @log.debug('ICFS check: %s' % title)

    # read
    json = @store.send(read, *read_args)
    if !json
      if hist
        @log.warn('ICFS check: %s is missing and historical' % title)
      else
        @log.error('ICFS check: %s is missing and current' % title)
      end
      return nil
    end

    # hash
    if hash
      if hash != ICFS.hash(json)
        @log.error('ICFS check: %s hash bad' % title)
      end
    else
      @log.warn('ICFS check: %s hash unverified' % title)
    end

    # parse
    obj = JSON.parse(json)
    err = Validate.check(obj, val)
    if err
      @log.error('ICFS check: %s bad format' % title)
      return nil
    end

    # inconsistent
    con.each do |name, num|
      if obj[name] != read_args[num]
        @log.error('ICFS check: %s inconsistent' % title)
        return nil
      end
    end

    return obj

  rescue JSON::ParserError
    @log.error('ICFS check: %s bad JSON' % title)
    return nil
  end # def _item()
  private :_item


  ###############################################
  # Check a case
  #
  # @param cur_log [Integer] The last log
  # @param cur_hash [String] The hash of the last log
  #
  def check(cid, cur_log, cur_hash, opts={})
    @log.info('ICFS check: case %s' % cid)

    ent_cur = Set.new
    cse_cur = false
    idx_cur = Set.new
    act_cur = Set.new
    file_cur = Set.new


    # go thru the logs from most current
    lnum = cur_log
    hash_log = cur_hash
    time_log = Time.now.to_i
    while( lnum > 0 )

      # log
      log = _item(
        'log %d' % lnum,
        :log_read,
        [cid, lnum],
        false,
        hash_log,
        Items::ItemLog,
        [
          ['caseid', 0].freeze,
          ['log', 1].freeze
        ].freeze,
      )
      if !log
        hash_log = nil
        lnum = lnum - 1
        next
      end

      # check that time decreases
      if log['time'] > time_log
        @log.warn('ICFS check: log %d time inconsistent' % lnum)
      end

      # entry
      if log['entry']
        enum = log['entry']['num']
        ent = _item(
          'entry %d-%d' % [enum, lnum],
          :entry_read,
          [cid, enum, lnum],
          ent_cur.include?(enum),
          log['entry']['hash'],
          Items::ItemEntry,
          [
            ['caseid', 0].freeze,
            ['entry', 1].freeze,
            ['log', 2].freeze
          ].freeze,
        )

        # current entry
        unless ent_cur.include?(enum)
          ent_cur.add(enum)
          if ent['files']
            ent['files'].each do |fd|
              file_cur.add( '%d-%d-%d' % [enum, fd['num'], fd['log']] )
            end
          end
        end
      end

      # index
      if log['index']
        xnum = log['index']['num']
        idx = _item(
          'index %d-%d'. freeze % [xnum, lnum],
          :index_read,
          [cid, xnum, lnum],
          idx_cur.include?(xnum),
          log['index']['hash'],
          Items::ItemIndex,
          [
            ['caseid', 0].freeze,
            ['index', 1].freeze,
            ['log', 2].freeze
          ]
        )
        idx_cur.add(xnum)
      end

      # action
      if log['action']
        anum = log['action']['num']
        act = _item(
          'action %d-%d' % [anum, lnum],
          :action_read,
          [cid, anum, lnum],
          act_cur.include?(anum),
          log['action']['hash'],
          Items::ItemAction,
          [
            ['caseid', 0].freeze,
            ['action', 1].freeze,
            ['log', 2].freeze
          ]
        )
        act_cur.add(anum)
      end

      # case
      if log['case']
        cse = _item(
          'case %d' % lnum,
          :case_read,
          [cid, lnum],
          cse_cur,
          log['case']['hash'],
          Items::ItemCase,
          [
            ['caseid', 0].freeze,
            ['log', 1].freeze
          ]
        )
        cse_cur = true
      end

      # files
      if log['files_hash']
        fnum = 0
        log['files_hash'].each do |hash|
          fnum = fnum + 1
          fn = '%d-%d-%d' % [enum, fnum, lnum]
          cur = file_cur.include?(fn)
          file_cur.delete(fn) if cur

          @log.debug('ICFS check: file %s' % fn)

          # read/size
          if opts[:hash_all] || (cur && opts[:hash_current])
            fi = @store.file_read(cid, enum, lnum, fnum)
          elsif opts[:stat_all] || (cur && opts[:stat_current])
            fi = @store.file_size(cur, enum, lnum, fnum)
          else
            fi = true
          end

          # missing
          if !fi
            if cur
              @log.error('ICFS check: file %s missing and current' %
                fn)
            else
              @log.warn('ICFS check: file %s missing and historical' %
                fn)
            end
          end

          # hash
          if fi.is_a?(File)
            # check
            if hash != ICFS.hash_temp(fi)
              @log.error('ICFS check: file %s hash bad' % fn)
            end

            # close
            if fi.respond_to?(:close!)
              fi.close!
            else
              fi.close
            end
          end
        end
      end

      # previous log
      lnum = lnum - 1
      hash_log = log['prev']
    end

    # check for any non-existant current files
    unless file_cur.empty?
      file_cur.each do |fn|
        @log.error('ICFS check: file %s current but not logged' % fn)
      end
    end

    @log.debug('ICFS check: case %s complete' % cid)
  end # def check()


end # class ICFS::Utils::Check

end # module ICFS::Utils
end # module ICFS
