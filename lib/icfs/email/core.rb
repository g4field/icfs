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

require 'set'

module ICFS


##########################################################################
# Email integration with ICFS
#
module Email


##########################################################################
# Core email processing engine.
#
class Core


  ###############################################
  # A file to attach
  ValFile = {
    method: :hash,
    required: {
      content: Validate::IsString,     # content of the file
      name: Items::FieldFilename,      # name of the file
    }.freeze
  }.freeze


  ###############################################
  # Results of processing a valid message
  ValReceive = {
    method: :hash,
    required: {
      orig: Validate::IsString,        # the raw message
      caseid: Items::FieldCaseid,      # case to write
      user: Items::FieldUsergrp,       # user as author
      files: {                         # files to attach
        method: :array,
        check: ValFile
      }.freeze,
    }.freeze,
    optional: {
      entry: Validate::IsIntPos,       # the entry number
      time: Validate::IsIntPos,        # the time of the entry
      title: Items::FieldTitle,        # title of the entry
      content: Items::FieldContent,    # content of the entry
      tags: {                          # tags to apply
        method: :array,
        check: Items::FieldTag
      }.freeze,
      perms: {                         # perms to apply
        method: :array,
        check: Items::FieldPermAny,
      }.freeze,
      stats: {                         # stats to apply
        method: :array,
        min: 1,
        check: {
          method: :hash,
          required: {
            "name" => Items::FieldStat,
            "value" => Validate::IsFloat,
            "credit" => {
              method: :array,
              min: 1,
              max: 32,
              check: Items::FieldUsergrp
            }.freeze
          }.freeze
        }.freeze
      }.freeze,
      save_raw: Validate::IsBoolean,   # save the raw email as a File
      save_msg: Validate::IsBoolean,   # save the processed message w/o attach
    }.freeze,
    others: true,
  }.freeze


  ###############################################
  # Default title
  DefaultTitle = 'Email gateway default title'


  ###############################################
  # Default content
  DefaultContent = 'Entry generated via email gateway with no content.'


  ###############################################
  # Filename for original content
  DefaultOrig = 'email_received.eml'


  ###############################################
  # Filename for processed content without attachments
  DefaultEmail = 'email.eml'


  ###############################################
  # New instance
  #
  # @param api [ICFS::Api] the ICFS API
  # @param log [Logger] The log
  # @param st [Array] the middleware
  #
  def initialize(api, log, st=nil)
    @api = api
    @log = log
    self.stack_set(st) if st
  end # def initialize()


  ###############################################
  # Set the middleware stack
  #
  # Each middleware object must respond to #receive and return one of:
  #  * :continue - process more middleware
  #  * :success - stops further middleare, and records the entry
  #  * :failure - stops further middlware and does not record
  #
  def stack_set(st)
    @stack = st
  end # def stack_set()


  ###############################################
  # Process a received email using the middleware stack
  #
  # @param msg [::Mail::Message] the email message
  # @return [Array] results, first field is a Symbol, second field is error or
  #   the recorded message
  #
  def receive(msg)
    @log.debug('Email: Processing %s' % msg.message_id)

    # setup the environment
    env = {
      orig: msg.raw_source.dup, # the original text email
      msg: msg,                 # the email message being worked on
      files: [],                # files to attach to the entry
      api: @api,                # the ICFS API
    }

    # process all middleware
    @stack.each do |mid|
      resp, err = mid.receive(env)
      case resp
      when :continue
        next
      when :stop
        break
      when :failure
        return [:failure, err]
      else
        raise ScriptError
      end
    end

    # check that all required fields were completed
    err = Validate.check(env, ValReceive)
    if err
      @log.info('Email: Invalid: %s' % err.inspect)
      return [:invalid, err]
    end

    # API set to active user
    @api.user = env[:user]

    # if an entry was specified
    if env[:entry] && env[:entry] != 0
      ent = @api.entry_read(env[:caseid], env[:entry])
      ent.delete('icfs')
      ent.delete('log')
      ent.delete('user')
      ent.delete('tags') if ent['tags'][0] == ICFS::TagNone
    else
      ent = {}
      ent['caseid'] = env[:caseid]
    end

    # build entry
    ent['time'] = env[:time] if env[:time]
    ent['title'] = env[:title] if env[:title]
    ent['title'] ||= DefaultTitle
    ent['content'] = env[:content] if env[:content]
    ent['content'] ||= DefaultContent
    if env[:tags]
      ent['tags'] ||= []
      ent['tags'] = (ent['tags'] + env[:tags]).uniq
    end
    ent['perms'] = env[:perms].uniq if env[:perms]
    ent['stats'] = env[:stats] if env[:stats]

    # files
    files = env[:files].map do |fd|
      tmp = @api.tempfile
      tmp.write(fd[:content])
      { 'name' => fd[:name], 'temp' => tmp }
    end
    if env[:save_original]
      tmp = @api.tempfile
      tmp.write(env[:orig])
      files << { 'name' => DefaultOrig, 'temp' => tmp }
    end
    if env[:save_email]
      tmp = @api.tempfile
      env[:msg].header.fields.delete_if do |fi|
        !FieldsSet.include?(fi.name.downcase)
      end
      tmp.write(env[:msg].encoded)
      files << { 'name' => DefaultEmail, 'temp' => tmp }
    end
    unless files.empty?
      ent['files'] ||= []
      ent['files'] = ent['files'] + files
    end

    # try to record it
    @api.record(ent, nil, nil, nil)

    @log.info('Email: Success: %s %d-%d' %
        [ent['caseid'], ent['entry'], ent['log']])
    return [:success, ent]

  rescue ICFS::Error::Conflict => ex
    @log.warn('Email: Conflict: %s' % ex.message)
    return [:conflict, ex.message]
  rescue ICFS::Error::NotFound => ex
    @log.warn('Email: Not Found: %s' % ex.message)
    return [:notfound, ex.message]
  rescue ICFS::Error::Perms => ex
    @log.warn('Email: Permissions: %s' % ex.message)
    return [:perms, ex.message]
  rescue ICFS::Error::Value => ex
    @log.warn('Email: Value: %s' % ex.message)
    return [:value, ex.message]
  end # def receive()


  ###############################################
  # Basic header fields to copy
  #
  CopyFields = [
    "to",
    "cc",
    "message-id",
    "in-reply-to",
    "references",
    "subject",
    "comments",
    "keywords",
    "date",
    "from",
    "sender",
    "reply-to",
  ].freeze


  ###############################################
  # Content related fields
  #
  ContentFields = [
    "content-transfer-encoding",
    "content-description",
    "content-disposition",
    "content-type",
    "content-id",
    "content-location",
  ].freeze


  ###############################################
  # Set of header fields to copy set
  FieldsSet = Set.new(CopyFields).merge(ContentFields).freeze

end # class ICFS::Email::Core


end # module ICFS::Email
end # module ICFS
