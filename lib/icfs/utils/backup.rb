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

require_relative '../store_fs'

module ICFS

module Utils

##########################################################################
# Backup and restore utilities
#
class Backup


  ###############################################
  # Instance
  #
  # @param cache [Cache] The live cache
  # @param store [Store] The live store
  # @param log [Logger] Where to log
  #
  def initialize(cache, store, log)
    @cache = cache
    @store = store
    @log = log
  end


  ###############################################
  # Copy an item
  #
  def _copy_item(dest, title, read, write, args, val=nil)
    @log.debug('ICFS copy: %s' % title)

    # read the item
    json = @store.send(read, *args)
    if !json
      @log.warn('ICFS copy: %s is missing' % title)
      return nil
    end

    # parse the item if requested
    if val
      obj = JSON.parse(json)
      err = Validate.check(obj, val)
      if err
        @log.error('ICFS copy: %s bad format' % title)
        return nil
      end
    end

    # write the item
    dest.send(write, *args, json)
    return obj

  rescue JSON::ParserError
    @log.error('ICFS copy: %s bad JSON' % title)
    return nil
  end # def _item
  private :_copy_item


  ###############################################
  # Transfer a case to another store
  #
  # @param cid [String] The case ID
  # @param dest [Store] The destination store
  # @param lnum_max [Integer] The highest log
  # @param lnum_min [Integer] The lowest log
  #
  def copy(cid, dest, lnum_min=1, lnum_max=0)
    @log.info('ICFS copy: %s %d-%d' % [cid, lnum_min, lnum_max])

    # if no max specified, pull from current
    if lnum_max == 0
      json = @cache.current_read(cid)
      cur = Items.parse(json, 'current', Items::ItemCurrent)
      lnum_max = cur['log']
    end

    if lnum_min > lnum_max
      raise ArgumentError, 'ICFS copy, log num min is larger than max'
    end

    # each log
    lnum = lnum_min
    while lnum <= lnum_max

      # copy the log
      log = _copy_item(dest,
        'log %d' % lnum,
        :log_read,
        :log_write,
        [cid, lnum],
        Items::ItemLog
      )
      if !log
        lnum += 1
        next
      end

      # entry
      enum = log['entry']['num']
      _copy_item(dest,
        'entry %d-%d' % [enum, lnum],
        :entry_read,
        :entry_write,
        [cid, enum, lnum]
      )

      # index
      if log['index']
        xnum = log['index']['num']
        _copy_item(dest,
          'index %d-%d' % [xnum, lnum],
          :index_read,
          :index_write,
          [cid, xnum, lnum]
        )
      end

      # action
      if log['action']
        anum = log['action']['num']
        _copy_item(dest,
          'action %d-%d' % [anum, lnum],
          :action_read,
          :action_write,
          [cid, anum, lnum]
        )
      end

      # case
      if log['case_hash']
        _copy_item(dest,
          'case %d' % lnum,
          :case_read,
          :case_write,
          [cid, lnum]
        )
      end

      # files
      if log['files_hash']
        log['files_hash'].each_index do |fraw|
          fnum = fraw + 1

          @log.debug('ICFS copy: file %d-%d-%d' % [enum, lnum, fnum])

          # read
          fi = @store.file_read(cid, enum, lnum, fnum)
          if !fi
            @log.warn('ICFS copy: file %d-%d-%d missing' %
                [enum, lnum, fnum])
            next
          end

          # copy
          tmp = dest.tempfile
          IO.copy_stream(fi, tmp)
          @store.close(fi)

          # write
          dest.file_write(cid, enum, lnum, fnum, tmp)
        end
      end

      lnum += 1
    end

  end # def copy()


  ###############################################
  # Restore an item
  #
  def _restore_item(src, title, read, write, args_st, args_ca, val=nil)
    @log.debug('ICFS restore: %s' % title)

    # read the item
    json = src.send(read, *args_st)
    if !json
      @log.warn('ICFS restore: %s is missing' % title)
      return nil
    end

    # parse item if requested
    if val
      obj = JSON.parse(json)
      err = Validate.check(obj, val)
      if err
        @log.error('ICFS restore: %s bad format' % title)
        return nil
      end
    end

    # write the item to store & cache
    @store.send(write, *args_st, json)
    @cache.send(write, *args_ca, json)
    return [obj, json]

  end # def _restore_item()
  private :_restore_item


  ###############################################
  # Restore a backup into a case
  #
  # @param cid [String] The case ID
  # @param src [Store] Source store
  # @param lnum_max [Integer] The highest log
  # @param lnum_min [Integer] The lowest log
  #
  def restore(cid, src, lnum_min=0, lnum_max=0)
    @log.info('ICFS restore: %s %d-%d' % [cid, lnum_min, lnum_max])

    # take lock
    @cache.lock_take(cid)
    begin

      # read current
      json = @cache.current_read(cid)
      if json
        cur = Items.parse(json, 'current', Items::ItemCurrent)
      else
        cur = {
          'icfs' => 1,
          'caseid' => cid,
          'log' => 1,
          'entry' => 1,
          'action' => 0,
          'index' => 0
        }
      end

      # if no min specified, pull from current or default to 1
      lnum_min = cur['log'] if lnum_min == 0

      # sanity check min & max
      if (lnum_min > lnum_max) && (lnum_max != 0)
        raise ArgumentError: 'ICFS restore, log min is larger than max'
      end

      # max entry, action, index
      emax = cur['entry']
      amax = cur['action']
      imax = cur['index']

      # each log
      lnum = lnum_min
      llast = nil
      while lnum != lnum_max

        # copy the log
        log, litem = _restore_item(src,
          'log %d' % lnum,
          :log_read,
          :log_write,
          [cid, lnum],
          [cid, lnum],
          Items::ItemLog
        )

        # no log - all done
        if !log
          break
        else
          llast = litem
        end

        # entry
        enum = log['entry']['num']
        _restore_item(src,
          'entry %d-%d' % [enum, lnum],
          :entry_read,
          :entry_write,
          [cid, enum, lnum],
          [cid, enum]
        )
        emax = enum if enum > emax

        # index
        if log['index']
          xnum = log['index']['num']
          _restore_item(src,
            'index %d-%d' % [xnum, lnum],
            :index_read,
            :index_write,
            [cid, xnum, lnum],
            [cid, xnum]
          )
          imax = xnum if xnum > imax
        end

        # action
        if log['action']
          anum = log['action']['num']
          _restore_item(src,
            'action %d-%d' % [anum, lnum],
            :action_read,
            :action_write,
            [cid, anum, lnum],
            [cid, anum]
          )
          amax = anum if anum > amax
        end

        # case
        if log['case_hash']
          _restore_item(src,
            'case %d' % lnum,
            :case_read,
            :case_write,
            [cid, lnum],
            [cid]
          )
        end

        # files
        if log['files_hash']
          log['files_hash'].each_index do |fraw|
            fnum = fraw + 1

            @log.debug('ICFS restore: file %d-%d-%d' % [enum, lnum, fnum])

            # read
            fi = src.file_read(cid, enum, lnum, fnum)
            if !fi
              @log.warn('ICFS restore: file %d-%d-%d missing' %
                [enum, lnum, fnum])
              next
            end

            # copy
            tmp = @store.tempfile
            IO.copy_stream(fi, tmp)
            src.close(fi)

            # write
            @store.file_write(cid, enum, lnum, fnum, tmp)
          end
        end

        lnum += 1
      end

      # write current
      cur = {
        'icfs' => 1,
        'caseid' => cid,
        'log' => lnum-1,
        'entry' => emax,
        'action' => amax,
        'index' => imax,
        'hash' => ICFS.hash(llast)
      }
      nitem = Items.generate(cur, 'current', Items::ItemCurrent)
      @cache.current_write(cid, nitem)

    ensure
      # release lock
      @cache.lock_release(cid)
    end

  end # def restore()


end # class ICFS::Utils::Backup

end # module ICFS::Utils

end # module ICFS
