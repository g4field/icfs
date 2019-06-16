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

require 'aws-sdk-s3'

module ICFS

##########################################################################
# Implements {ICFS::Users Users} from AWS S3
#
class UsersS3 < Users

  ###############################################
  # New instance
  #
  # @param s3 [Aws::S3::Client] the configured S3 client
  # @param bucket [String] The bucket name
  # @param prefix [String] Prefix to use for object keys
  #
  def initialize(s3, bucket, prefix=nil)
    @s3 = s3
    @bck = bucket
    @pre = prefix || ''
  end


  ###############################################
  # Where to store user
  #
  def _path(user)
    @pre + user + '.json'
  end # def _path()
  private :_path


  ###############################################
  # (see Users#flush)
  #
  def flush(urg); false; end


  ###############################################
  # (see Users#read)
  #
  def read(urg)
    Items.validate(urg, 'User/Role/Group name', Items::FieldUsergrp)
    json = @s3.get_object( bucket: @bck, key: _path(urg) ).body.read
    return JSON.parse(json)
  rescue
    return nil
  end # def read()


  ###############################################
  # (see Users#write)
  #
  def write(obj)
    Items.validate(obj, 'User/Role/Group', Users::ValUser)
    json = JSON.pretty_generate(obj)
    @s3.put_object( bucket: @bck, key: _path(obj['name']), body: json )
  end # def write()


end # class ICFS::UsersS3

end # module ICFS
