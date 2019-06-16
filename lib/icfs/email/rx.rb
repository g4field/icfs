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

require 'mail'

module ICFS


##########################################################################
# Email integration with ICFS
#
module Email


##########################################################################
# Process received email, resulting in a new Entry
#
class Rx


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
      raw: Validate::IsString,         # the raw message
      caseid: Items::FieldCaseid,      # case to write
      user: Items::FieldUsergrp,       # user as author
      files: {                         # files to attach
        method: :array,
        check: ValFile
      }.freeze,
    }.freeze,
    optional: {
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
  # Filename for raw content
  DefaultRaw = 'email_raw.eml'


  ###############################################
  # Filename for processed content without attachments
  DefaultMsg = 'email.eml'


  ###############################################
  # New instance
  #
  # @param api [ICFS::Api] the ICFS API
  # @param st [Array] the middleware
  #
  def initialize(api, st=nil)
    @api = api
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
  # @param txt [String] the email message as text
  # @return [Array] results, first field is a Symbol, second field is error or
  #   the recorded message
  #
  def receive(txt)

    # setup the environment
    env = {
      raw: txt.freeze,        # the original text email
      msg: Mail.new(txt),     # the email message being worked on
      files: [],              # files to attach to the entry
    }

    # process all middleware
    @stack.each do |mid|
      resp = mid.receive(env)
      case resp
      when :continue
        next
      when :success
        break
      when :failure
        return false
      else
        raise NotImplementedError
      end
    end

    # check that all required fields were completed
    err = Validate.check(env, ValReceive)
    return [:incomplete, err] if err

    # build entry
    ent = {}
    ent['caseid'] = env[:caseid]
    ent['time'] = env[:time] if env[:time]
    ent['title'] = env[:title] || DefaultTitle
    ent['content'] = env[:content] || DefaultContent
    ent['tags'] = env[:tags].uniq if env[:tags]
    ent['perms'] = env[:perms].uniq if env[:perms]

    # files
    files = env[:files].map do |fd|
      tmp = @api.tempfile
      tmp.write(fd[:content])
      { 'name' => fd[:name], 'temp' => tmp }
    end
    if env[:save_raw]
      tmp = @api.tempfile
      tmp.write(env[:raw])
      files << { 'name' => DefaultRaw, 'temp' => tmp }
    end
    if env[:save_msg]
      tmp = @api.tempfile
      tmp.write(env[:msg].without_attachments!.encoded)
      files << { 'name' => DefaultMsg, 'temp' => tmp }
    end
    ent['files'] = files unless files.empty?

    # try to record it
    begin
      @api.user = env[:user]
      @api.record(ent, nil, nil, nil)
    rescue ICFS::Error::Conflict => ex
      return [:conflict, ex.message]
    rescue ICFS::Error::NotFound => ex
      return [:notfound, ex.message]
    rescue ICFS::Error::Perms => ex
      return [:perms, ex.message]
    rescue ICFS::Error::Value => ex
      return [:value, ex.message]
    end

    return [:success, ent]
  end # def receive()


end # class ICFS::Email::Rx


end # module ICFS::Email
end # module ICFS
