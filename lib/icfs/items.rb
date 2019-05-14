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
    opts: {
      min: 1,
      max: 1,
    }.freeze
  }.freeze


  # Caseid
  FieldCaseid = {
    method: :string,
    opts: {
      min: 1,
      max: 32,
      invalid: /[[:cntrl:][:space:]"\#$%'()*+\/;<=>?@\[\]\\^`{|}~]/.freeze,
    }.freeze
  }.freeze


  # Title
  FieldTitle = {
    method: :string,
    opts: {
      min: 1,
      max: 128,
      invalid: /[[:cntrl:]]/.freeze,
    }.freeze
  }.freeze


  # Tag
  # No control characters
  # may not start with brackets or whitespace
  FieldTag = {
    method: :string,
    opts: {
      min: 1,
      max: 32,
      invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
    }.freeze
  }.freeze


  # Tag for Entry
  FieldTagEntry = {
    method: :string,
    opts: {
      min: 1,
      max: 32,
      allowed: Set[
        ICFS::TagAction,
        ICFS::TagIndex,
        ICFS::TagCase,
      ].freeze,
      invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
    }.freeze
  }.freeze


  # Special tags
  FieldTagSpecial = {
    method: :string,
    opts: {
      allowed: Set[
        ICFS::TagNone,
        ICFS::TagAction,
        ICFS::TagIndex,
        ICFS::TagCase,
      ].freeze,
      whitelist: true,
    }.freeze
  }.freeze


  # Any tag, including empty
  FieldTagAny = {
    method: :any,
    opts: {
      check: [
        FieldTag,
        FieldTagSpecial
      ].freeze,
    }.freeze
  }.freeze


  # a normal perm name
  # No control characters
  # may not start with square brackets, curly brackets, or whitespace
  FieldPermNormal = {
    method: :string,
    opts: {
      min: 1,
      max: 64,
      invalid: /[[:cntrl:]]|^[\[\{ ]/.freeze,
    }.freeze
  }.freeze


  # A reserved case name
  # square brackets
  FieldPermReserve = {
    method: :string,
    opts: {
      allowed: Set[
        ICFS::PermRead,
        ICFS::PermWrite,
        ICFS::PermManage,
        ICFS::PermAction
      ].freeze,
      whitelist: true
    }.freeze,
  }.freeze


  # A global permission
  # curly brackets, no control characters
  FieldPermGlobal = {
    method: :string,
    opts: {
      min: 1,
      max: 64,
      valid: /^\{[^[:cntrl:]]+\}$/.freeze,
      whitelist: true,
    }.freeze
  }.freeze


  # A case perm
  FieldPermCase = {
    method: :any,
    opts: {
      check: [
        FieldPermNormal,
        FieldPermReserve,
      ].freeze
    }.freeze
  }.freeze


  # Any perm
  FieldPermAny = {
    method: :any,
    opts: {
      check: [
        FieldPermNormal,
        FieldPermReserve,
        FieldPermGlobal,
      ].freeze
    }.freeze
  }.freeze


  # a user/group name
  # No control characters
  # no space, no punctuation except , - : _
  FieldUsergrp = {
    method: :string,
    opts: {
      min: 3,
      max: 32,
      invalid: /[\x00-\x2b\x2e\x2f\x3b-\x40\x5b-\x5e\x60\x7b-\x7f]/.freeze,
    }.freeze
  }.freeze


  # a hash
  FieldHash = {
    method: :string,
    opts: {
      min: 64,
      max: 64,
      invalid: /[^0-9a-f]/.freeze
    }.freeze
  }.freeze


  # Content
  FieldContent = {
    method: :string,
    opts: {
      min: 1,
      max: 8*1024,
      invalid: /[^[:graph:][:space:]]/.freeze,
    }.freeze
  }.freeze


  # a stat name
  FieldStat = {
    method: :string,
    opts: {
      min: 1,
      max: 32,
      invalid: /[[:cntrl:]\t\r\n\v\f]|^_/.freeze,
    }.freeze
  }.freeze


  # a filename
  FieldFilename = {
    method: :string,
    opts: {
      min: 1,
      max: 128,
      invalid: /[[:cntrl:]\\\/]|^\./.freeze
    }.freeze
  }.freeze


  ##############################################################
  # Sub-item parts
  ##############################################################

  # Empty Tags
  #
  SubTagsEmpty = {
    method: :array,
    opts: {
      min: 1,
      max: 1,
      check: {
        method: :equals,
        opts: { check: ICFS::TagNone }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Entry Tags
  #
  SubTagsEntry = {
    method: :array,
    opts: {
      min: 1,
      check: FieldTagEntry
    }.freeze
  }.freeze


  # Tags
  SubTagsNormal = {
    method: :array,
    opts: {
      min: 1,
      check: FieldTag
    }.freeze
  }.freeze


  # Tags
  SubTags = {
    method: :any,
    opts: {
      check: [ SubTagsEmpty, SubTagsNormal ].freeze
    }.freeze
  }.freeze


  # Grant
  SubGrant = {
    method: :hash,
    opts: {
      required: {
        'perm' => FieldPermCase,
        'grant' => {
          method: :array,
          opts: {
            min: 1,
            check: FieldUsergrp
          }.freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Access
  SubAccess = {
    method: :array,
    opts: {
      min: 1,
      check: SubGrant
    }.freeze
  }.freeze


  # Case stats
  SubCaseStats = {
    method: :array,
    opts: {
      min:1,
      check: FieldStat,
    }.freeze,
  }.freeze


  # An item in a log
  SubLogItem = {
    method: :hash,
    opts: {
      required: {
        'num' => Validate::ValIntPos,
        'hash' => FieldHash,
      }.freeze
    }.freeze
  }.freeze


  # Indexes
  SubIndexes = {
    method: :array,
    opts: {
      min: 1,
      check: Validate::ValIntPos,
    }.freeze,
  }.freeze


  # Perms
  SubPerms = {
    method: :array,
    opts: {
      min: 1,
      check: FieldPermAny
    }.freeze
  }.freeze


  # Stats
  SubStats = {
    method: :array,
    opts: {
      min: 1,
      check: {
        method: :hash,
        opts: {
          required: {
            "name" => FieldStat,
            "value" => Validate::ValFloat,
            "credit" => {
              method: :array,
              opts: {
                min: 1,
                max: 32,
                check: FieldUsergrp
              }.freeze
            }.freeze
          }.freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # An old file
  SubFileOld = {
    method: :hash,
    opts: {
      required: {
        'log' => Validate::ValIntPos,
        'num' => Validate::ValIntUns,
        'name' => FieldFilename,
      }.freeze
    }.freeze
  }.freeze


  # Case task
  SubTaskCase = {
    method: :hash,
    opts: {
      required: {
        'assigned' => {
          method: :string,
          opts: {
            allowed: Set[ ICFS::UserCase ].freeze,
            whitelist: true
          }.freeze
        }.freeze,
        'title' => FieldTitle,
        'status' => Validate::ValBoolean,
        'flag' => Validate::ValBoolean,
        'time' => Validate::ValIntPos,
        'tags' => SubTags
      }.freeze
    }.freeze
  }.freeze


  # Normal task
  SubTaskNormal = {
    method: :hash,
    opts: {
      required: {
        'assigned' => FieldUsergrp,
        'title' => FieldTitle,
        'status' => Validate::ValBoolean,
        'flag' => Validate::ValBoolean,
        'time' => Validate::ValIntPos,
        'tags' => SubTags
      }.freeze
    }.freeze
  }.freeze


  # Tasks
  SubTasks = {
    method: :array,
    opts: {
      min: 1,
      0 => SubTaskCase,
      check: SubTaskNormal
    }.freeze
  }.freeze


  # Case task
  SubTaskEditCase = {
    method: :hash,
    opts: {
      required: {
        'assigned' => {
          method: :string,
          opts: {
            allowed: Set[ ICFS::UserCase ].freeze,
            whitelist: true
          }.freeze
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
  }.freeze


  # Normal task
  SubTaskEditNormal = {
    method: :hash,
    opts: {
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
  }.freeze


  # TasksEdit
  SubTasksEdit = {
    method: :array,
    opts: {
      min: 1,
      0 => SubTaskEditCase,
      check: SubTaskEditNormal,
    }.freeze
  }.freeze


  # A new file
  SubFileNew = {
    method: :hash,
    opts: {
      required: {
        'temp' => Validate::ValTempfile,
        'name' => FieldFilename,
      }.freeze
    }.freeze
  }.freeze


  ##############################################################
  # Check Items
  ##############################################################


  # Case - Edit
  ItemCaseEdit = {
    method: :hash,
    opts: {
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
  }.freeze


  # Entry - New only
  ItemEntryNew = {
    method: :hash,
    opts: {
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
          opts: {
            min: 1,
            check: SubFileNew
          }.freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Entry - Edit or New
  ItemEntryEdit = {
    method: :hash,
    opts: {
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
          opts: {
            min: 1,
            check: {
              method: :any,
              opts: {
                check: [ SubFileOld, SubFileNew ].freeze
              }.freeze
            }.freeze
          }.freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Action - Edit or New
  ItemActionEdit = {
    method: :hash,
    opts: {
      required: {
        'tasks' => SubTasksEdit
      }.freeze,
      optional: {
        'action' => Validate::ValIntPos
      }.freeze
    }.freeze,
  }.freeze


  # Index - Edit or New
  ItemIndexEdit = {
    method: :hash,
    opts: {
      required: {
        'title' => FieldTitle,
        'content' => FieldContent,
      }.freeze,
      optional: {
        'index' => Validate::ValIntPos,
        'tags' => SubTags,
      }.freeze
    }.freeze,
  }.freeze


  ##############################################################
  # Recorded items
  ##############################################################

  # Case
  ItemCase = {
    method: :hash,
    opts: {
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
  }.freeze


  # Log
  ItemLog = {
    method: :hash,
    opts: {
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
          opts: {
            min: 1,
            check: FieldHash,
          }.freeze
        }.freeze,
      }.freeze,
    }.freeze
  }.freeze


  # Entry
  ItemEntry = {
    method: :hash,
    opts: {
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
          opts: {
            check: [
              SubTagsEmpty,
              SubTagsEntry,
            ].freeze
          }.freeze
        }.freeze,
      }.freeze,
      optional: {
        'index' => SubIndexes,
        'action' => Validate::ValIntPos,
        'perms' => SubPerms,
        'stats' => SubStats,
        'files' => {
          method: :array,
          opts: {
            min: 1,
            check: SubFileOld,
          }.freeze
        }.freeze
      }.freeze
    }.freeze
  }.freeze


  # Action
  ItemAction = {
    method: :hash,
    opts: {
      required: {
        'icfs' => FieldIcfs,
        'caseid' => FieldCaseid,
        'action' => Validate::ValIntPos,
        'log' => Validate::ValIntPos,
        'tasks' => SubTasks
      }.freeze
    }.freeze
  }.freeze


  # Index
  ItemIndex = {
    method: :hash,
    opts: {
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
  }.freeze


  # Current
  ItemCurrent = {
    method: :hash,
    opts: {
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
  }.freeze


end # module ICFS::Items

end # module ICFS
