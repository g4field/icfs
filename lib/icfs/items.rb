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
# Items
#
module Items

  ##############################################################
  # Base fields
  ##############################################################

  # ICFS version
  FieldIcfs = {
    method: :integer,
    min: 1,
    max: 1,
  }.freeze


  # Caseid
  FieldCaseid = {
    method: :string,
    min: 1,
    max: 32,
    invalid: /[[:cntrl:][:space:]"\#$%'()*+\/;<=>?@\[\]\\^`{|}~]/.freeze,
  }.freeze


  # Title
  FieldTitle = {
    method: :string,
    min: 1,
    max: 128,
    invalid: /[[:cntrl:]]/.freeze,
  }.freeze


  # Tag
  # No control characters
  # may not start with brackets or whitespace
  FieldTag = {
    method: :string,
    min: 1,
    max: 32,
    invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
  }.freeze


  # Tag for Entry
  FieldTagEntry = {
    method: :string,
    min: 1,
    max: 32,
    allowed: Set[
      ICFS::TagAction,
      ICFS::TagIndex,
      ICFS::TagCase,
    ].freeze,
    invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
  }.freeze


  # Special tags
  FieldTagSpecial = {
    method: :string,
    allowed: Set[
      ICFS::TagNone,
      ICFS::TagAction,
      ICFS::TagIndex,
      ICFS::TagCase,
    ].freeze,
    whitelist: true,
  }.freeze


  # Any tag, including empty
  FieldTagAny = {
    method: :any,
    check: [
      FieldTag,
      FieldTagSpecial
    ].freeze,
  }.freeze


  # a normal perm name
  # No control characters
  # may not start with square brackets, curly brackets, or whitespace
  FieldPermNormal = {
    method: :string,
    min: 1,
    max: 64,
    invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
  }.freeze


  # A reserved case name
  # square brackets
  FieldPermReserve = {
    method: :string,
    allowed: Set[
      ICFS::PermRead,
      ICFS::PermWrite,
      ICFS::PermManage,
      ICFS::PermAction
    ].freeze,
    whitelist: true
  }.freeze


  # A global permission
  # curly brackets, no control characters
  FieldPermGlobal = {
    method: :string,
    min: 1,
    max: 64,
    valid: /^\{[^[:cntrl:]]+\}$/.freeze,
    whitelist: true,
  }.freeze


  # A case perm
  FieldPermCase = {
    method: :any,
    check: [
      FieldPermNormal,
      FieldPermReserve,
    ].freeze
  }.freeze


  # Any perm
  FieldPermAny = {
    method: :any,
    check: [
      FieldPermNormal,
      FieldPermReserve,
      FieldPermGlobal,
    ].freeze
  }.freeze


  # a user/group name
  # No control characters
  # no space, no punctuation except , - : _
  FieldUsergrp = {
    method: :string,
    min: 3,
    max: 32,
    invalid: /[\x00-\x2b\x2e\x2f\x3b-\x40\x5b-\x5e\x60\x7b-\x7f]/.freeze,
  }.freeze


  # a hash
  FieldHash = {
    method: :string,
    min: 64,
    max: 64,
    invalid: /[^0-9a-f]/.freeze
  }.freeze


  # Content
  FieldContent = {
    method: :string,
    min: 1,
    max: 8*1024,
    invalid: /[^[:graph:][:space:]]/.freeze,
  }.freeze


  # a stat name
  FieldStat = {
    method: :string,
    min: 1,
    max: 32,
    invalid: /[[:cntrl:]\t\r\n\v\f]|^_/.freeze,
  }.freeze


  # a filename
  FieldFilename = {
    method: :string,
    min: 1,
    max: 128,
    invalid: /[[:cntrl:]\\\/]|^\./.freeze
  }.freeze


  ##############################################################
  # Sub-item parts
  ##############################################################

  # Empty Tags
  #
  SubTagsEmpty = {
    method: :array,
    min: 1,
    max: 1,
    check: {
      method: :equals,
      check: ICFS::TagNone
    }.freeze
  }.freeze


  # Entry Tags
  #
  SubTagsEntry = {
    method: :array,
    min: 1,
    check: FieldTagEntry
  }.freeze


  # Tags
  SubTagsNormal = {
    method: :array,
    min: 1,
    check: FieldTag
  }.freeze


  # Tags
  SubTags = {
    method: :any,
    check: [ SubTagsEmpty, SubTagsNormal ].freeze
  }.freeze


  # Grant
  SubGrant = {
    method: :hash,
    required: {
      'perm' => FieldPermCase,
      'grant' => {
        method: :array,
        min: 1,
        check: FieldUsergrp
      }.freeze
    }.freeze
  }.freeze


  # Access
  SubAccess = {
    method: :array,
    min: 1,
    check: SubGrant
  }.freeze


  # Case stats
  SubCaseStats = {
    method: :array,
    min:1,
    check: FieldStat,
  }.freeze


  # An item in a log
  SubLogItem = {
    method: :hash,
    required: {
      'num' => Validate::ValIntPos,
      'hash' => FieldHash,
    }.freeze
  }.freeze


  # Indexes
  SubIndexes = {
    method: :array,
    min: 1,
    check: Validate::ValIntPos,
  }.freeze


  # Perms
  SubPerms = {
    method: :array,
    min: 1,
    check: FieldPermAny
  }.freeze


  # Stats
  SubStats = {
    method: :array,
    min: 1,
    check: {
      method: :hash,
      required: {
        "name" => FieldStat,
        "value" => Validate::ValFloat,
        "credit" => {
          method: :array,
          min: 1,
          max: 32,
          check: FieldUsergrp
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # An old file
  SubFileOld = {
    method: :hash,
    required: {
      'log' => Validate::ValIntPos,
      'num' => Validate::ValIntUns,
      'name' => FieldFilename,
    }.freeze
  }.freeze


  # Case task
  SubTaskCase = {
    method: :hash,
    required: {
      'assigned' => {
        method: :string,
        allowed: Set[ ICFS::UserCase ].freeze,
        whitelist: true
      }.freeze,
      'title' => FieldTitle,
      'status' => Validate::ValBoolean,
      'flag' => Validate::ValBoolean,
      'time' => Validate::ValIntPos,
      'tags' => SubTags
    }.freeze
  }.freeze


  # Normal task
  SubTaskNormal = {
    method: :hash,
    required: {
      'assigned' => FieldUsergrp,
      'title' => FieldTitle,
      'status' => Validate::ValBoolean,
      'flag' => Validate::ValBoolean,
      'time' => Validate::ValIntPos,
      'tags' => SubTags
    }.freeze
  }.freeze


  # Tasks
  SubTasks = {
    method: :array,
    min: 1,
    0 => SubTaskCase,
    check: SubTaskNormal
  }.freeze


  # Case task
  SubTaskEditCase = {
    method: :hash,
    required: {
      'assigned' => {
        method: :string,
        allowed: Set[ ICFS::UserCase ].freeze,
        whitelist: true
      }.freeze,
      'title' => FieldTitle,
      'status' => Validate::ValBoolean,
      'flag' => Validate::ValBoolean,
      'time' => Validate::ValIntPos,
    }.freeze,
    optional: {
      'tags' => SubTags
    }.freeze
  }.freeze


  # Normal task
  SubTaskEditNormal = {
    method: :hash,
    required: {
      'assigned' => FieldUsergrp,
      'title' => FieldTitle,
      'status' => Validate::ValBoolean,
      'flag' => Validate::ValBoolean,
      'time' => Validate::ValIntPos,
    }.freeze,
    optional: {
      'tags' => SubTags
    }.freeze
  }.freeze


  # TasksEdit
  SubTasksEdit = {
    method: :array,
    min: 1,
    0 => SubTaskEditCase,
    check: SubTaskEditNormal,
  }.freeze


  # A new file
  SubFileNew = {
    method: :hash,
    required: {
      'temp' => Validate::ValTempfile,
      'name' => FieldFilename,
    }.freeze
  }.freeze


  ##############################################################
  # Check Items
  ##############################################################


  # Case - Edit
  ItemCaseEdit = {
    method: :hash,
    required: {
      'template' => Validate::ValBoolean,
      'status' => Validate::ValBoolean,
      'title' => FieldTitle,
      'access' => SubAccess
    }.freeze,
    optional: {
      'tags' => SubTags,
      'stats' => SubCaseStats,
    }.freeze
  }.freeze


  # Entry - New only
  ItemEntryNew = {
    method: :hash,
    required: {
      'caseid' => FieldCaseid,
      'title' => FieldTitle,
      'content' => FieldContent,
    }.freeze,
    optional: {
      'time' => Validate::ValIntPos,
      'tags' => SubTagsNormal,
      'index' => SubIndexes,
      'action' => Validate::ValIntPos,
      'perms' => SubPerms,
      'stats' => SubStats,
      'files' => {
        method: :array,
        min: 1,
        check: SubFileNew
      }.freeze
    }.freeze
  }.freeze


  # Entry - Edit or New
  ItemEntryEdit = {
    method: :hash,
    required: {
      'caseid' => FieldCaseid,
      'title' => FieldTitle,
      'content' => FieldContent,
    }.freeze,
    optional: {
      'entry' => Validate::ValIntPos,
      'time' => Validate::ValIntPos,
      'tags' => SubTagsEntry,
      'index' => SubIndexes,
      'action' => Validate::ValIntPos,
      'perms' => SubPerms,
      'stats' => SubStats,
      'files' => {
        method: :array,
        min: 1,
        check: {
          method: :any,
          check: [ SubFileOld, SubFileNew ].freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Action - Edit or New
  ItemActionEdit = {
    method: :hash,
    required: {
      'tasks' => SubTasksEdit
    }.freeze,
    optional: {
      'action' => Validate::ValIntPos
    }.freeze
  }.freeze


  # Index - Edit or New
  ItemIndexEdit = {
    method: :hash,
    required: {
      'title' => FieldTitle,
      'content' => FieldContent,
    }.freeze,
    optional: {
      'index' => Validate::ValIntPos,
      'tags' => SubTags,
    }.freeze
  }.freeze


  ##############################################################
  # Recorded items
  ##############################################################

  # Case
  ItemCase = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'log' => Validate::ValIntPos,
      'template' => Validate::ValBoolean,
      'status' => Validate::ValBoolean,
      'title' => FieldTitle,
      'tags' => SubTags,
      'access' => SubAccess,
    }.freeze,
    optional: {
      'stats' => SubCaseStats,
    }.freeze,
  }.freeze


  # Log
  ItemLog = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'log' => Validate::ValIntPos,
      'prev' => FieldHash,
      'time' => Validate::ValIntPos,
      'user' => FieldUsergrp,
      'entry' => SubLogItem,
    }.freeze,
    optional: {
      'index' => SubLogItem,
      'action' => SubLogItem,
      'case_hash' => FieldHash,
      'files_hash' => {
        method: :array,
        min: 1,
        check: FieldHash
      }.freeze,
    }.freeze,
  }.freeze


  # Entry
  ItemEntry = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'entry' => Validate::ValIntPos,
      'log' => Validate::ValIntPos,
      'user' => FieldUsergrp,
      'time' => Validate::ValIntPos,
      'title' => FieldTitle,
      'content' => FieldContent,
      'tags' => {
        method: :any,
        check: [
          SubTagsEmpty,
          SubTagsEntry,
        ].freeze
      }.freeze,
    }.freeze,
    optional: {
      'index' => SubIndexes,
      'action' => Validate::ValIntPos,
      'perms' => SubPerms,
      'stats' => SubStats,
      'files' => {
        method: :array,
        min: 1,
        check: SubFileOld
      }.freeze
    }.freeze
  }.freeze


  # Action
  ItemAction = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'action' => Validate::ValIntPos,
      'log' => Validate::ValIntPos,
      'tasks' => SubTasks
    }.freeze
  }.freeze


  # Index
  ItemIndex = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'index' => Validate::ValIntPos,
      'log' => Validate::ValIntPos,
      'title' => FieldTitle,
      'content' => FieldContent,
      'tags' => SubTags
    }.freeze,
  }.freeze


  # Current
  ItemCurrent = {
    method: :hash,
    required: {
      'icfs' => FieldIcfs,
      'caseid' => FieldCaseid,
      'log' => Validate::ValIntPos,
      'hash' => FieldHash,
      'entry' => Validate::ValIntPos,
      'action' => Validate::ValIntUns,
      'index' => Validate::ValIntUns,
    }.freeze
  }.freeze


end # module ICFS::Items

end # module ICFS
