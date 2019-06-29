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

require 'digest/sha2'
require 'date'

require_relative 'icfs/validate'

##########################################################################
# Investigative Case File System
#
module ICFS

  # version: major, minor, patch
  Version = [0, 2, 0].freeze

  # version pre-release
  VersionPre = nil

  # version string
  VersionString = (
    '%d.%d.%d' % Version +
    (VersionPre ? ('-' + VersionPre) : '')
  ).freeze

  # no tags
  TagNone = '[none]'

  # edits an action
  TagAction = '[action]'

  # edits an index
  TagIndex = '[index]'

  # edits the case
  TagCase = '[case]'


  # permission to read case
  PermRead = '[read]'

  # permission to write case
  PermWrite = '[write]'

  # permission to manage case
  PermManage = '[manage]'

  # permission to manage actions
  PermAction = '[action]'

  # global permission to search
  PermSearch = '{[search]}'


  # user group
  UserCase = '[case]'


  ###############################################
  # Hash a string
  def self.hash(str)
    Digest::SHA256.hexdigest(str)
  end


  ###############################################
  # Hash a tempfile
  #
  def self.hash_temp(tf)
    Digest::SHA256.file(tf.path).hexdigest
  end


  ###############################################
  # Pull a time type
  #
  # @api private
  #
  def self._time_type(str)
    case str.downcase
    when 'y', 'yr', 'yrs', 'year', 'years'
      return :year
    when 'm', 'mon', 'mons', 'month', 'months'
      return :month
    when 'w', 'wk', 'wks', 'week', 'weeks'
      return :week
    when 'd', 'day', 'days'
      return :day
    when 'h', 'hr', 'hrs', 'hour', 'hours'
      return :hour
    when 'min', 'mins', 'minute', 'minutes'
      return :minute
    when 's', 'sec', 'secs', 'second', 'seconds'
      return :second
    else
      return nil
    end
  end # self._time_type()


  ###############################################
  # Adjust the time
  #
  # @api private
  #
  def self._time_adjust(num, type)
    case type
    when :year
      ary = Time.now.utc.to_a
      dte = Date.new(ary[5], ary[4], ary[3])
      dte = dte << (-12 * num)
      return Time.utc(dte.year, dte.month, dte.day,
          ary[2], ary[1], ary[0]).to_i
    when :month
      ary = Time.now.utc.to_a
      dte = Date.new(ary[5], ary[4], ary[3])
      dte = dte << (-1 * num)
      return Time.utc(dte.year, dte.month, dte.day,
          ary[2], ary[1], ary[0]).to_i
    when :week
      return (Time.now + num * 7*24*60*60).to_i
    when :day
      return (Time.now + num * 24*60*60).to_i
    when :hour
      return (Time.now + num * 60*60).to_i
    when :minute
      return (Time.now + num * 60).to_i
    when :second
      return (Time.now + num).to_i
    else
      return nil
    end
  end


  ###############################################
  # A time delta spec
  TimeDelta = /^[[:space:]]*([Nn][Oo][Ww])?[[:space:]]*([+\-])[[:space:]]*(\d+)[[:space:]]*([^[space]]+)[[:space]]*$/.freeze


  ###############################################
  # a relative spec
  TimeRel = /^[[:space:]]*([Nn][Ee][Xx][Tt]|[Pp][Rr][Ee][Vv]|[Ll][Aa][Ss][Tt])[[:space:]]+([^[:space:]]+)[[:space:]]*$/.freeze


  ###############################################
  # future time spec
  TimeFuture = /^[[:space:]]*[Ii][Nn][[:space:]]+(\d+)[[:space:]]*([^[space]]+)[[:space]]*$/.freeze


  ###############################################
  # historic time spec
  TimeHistory = /^[[:space:]]*(\d+)[[:space:]]*([^[:space:]]+)[[:space:]]*[Aa][Gg][Oo][[:space:]]*$/.freeze


  ###############################################
  # empty time spec
  TimeEmpty = /^[[:space:]]*([Nn][Oo][Ww])?[[:space:]]*$/.freeze


  ###############################################
  # A timezone spec
  TimeZone = /[+\-]\d{2}:\d{2}[[:space:]]*$/.freeze


  ###############################################
  # Parse a time string
  #
  # @param str [String] the time string
  # @param cfg [Config] the config
  #
  # Handles:
  # * blank or now
  # * \[now\] +\\- <num> <type>
  # * next\\prev <type>
  # * in <num> <type>
  # * <num> <type> ago
  # * a specifc parseable time
  #
  def self.time_parse(str, cfg)
    return nil if( !str || !str.is_a?(String) )

    # empty
    if ma = TimeEmpty.match(str)
      return Time.now.to_i

    # delta
    elsif ma = TimeDelta.match(str)
      num = ma[3].to_i
      num = num * -1 if ma[2] == '-'
      type = ICFS._time_type(ma[4])
      return ICFS._time_adjust(num, type)

    # relative
    elsif ma = TimeRel.match(str)
      num = (ma[1].downcase == 'next') ? 1 : -1
      type = ICFS._time_type(ma[2])
      return ICFS._time_adjust(num, type)

    # future
    elsif ma = TimeFuture.match(str)
      num = ma[1].to_i
      type = ICFS._time_type(ma[2])
      return ICFS._time_adjust(num, type)

    # history
    elsif ma = TimeHistory.match(str)
      p ma
      num = -1 * ma[1].to_i
      type = ICFS._time_type(ma[2])
      return ICFS._time_adjust(num, type)

    # parse a time spec
    else
      ma = TimeZone.match(str)
      tstr = ma ? str : str + cfg.get('tz')
      return Time.parse(tstr).to_i

    end

  rescue ArgumentError
    return nil
  end # def self.time_parse()


##########################################################################
# Error
#
module Error


##########################################################################
# Invalid values
class Value < ArgumentError; end

##########################################################################
# Item not found
class NotFound < RuntimeError; end

##########################################################################
# Do not have required permissions
class Perms < RuntimeError; end

##########################################################################
# Conflict with pre-existing values
class Conflict < RuntimeError; end

##########################################################################
# Interface errors
class Interface < RuntimeError; end

end # module ICFS::Error

end # module ICFS

require_relative 'icfs/cache'
require_relative 'icfs/store'
require_relative 'icfs/items'
require_relative 'icfs/api'
require_relative 'icfs/users'
