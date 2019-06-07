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

require_relative 'config'

module ICFS
module Web

##########################################################################
# Configuration storage implemented in S3
#
class ConfigS3 < Config


  ###############################################
  # New instance
  #
  # @param defaults [Hash] The default options
  # @param s3 [Aws::S3::Client] the configured S3 client
  # @param bucket [String] The bucket name
  # @param prefix [String] Prefix to use for object keys
  #
  def initialize(defaults, s3, bucket, prefix=nil)
    super(defaults)
    @s3 = s3
    @bck = bucket
    @pre = prefix || ''.freeze
  end


  ###############################################
  # (see Config#load)
  #
  def load(unam)
    Items.validate(unam, 'User/Role/Group name'.freeze, Items::FieldUsergrp)
    @unam = unam.dup
    json = @s3.get_object( bucket: @bck, key: _key(unam) ).body.read
    @data = Items.parse(json, 'Config values'.freeze, Config::ValConfig)
    return true
  rescue
    @data = {}
    return false
  end # def load()


  ###############################################
  # (see Config#save)
  #
  def save()
    raise(RuntimeError, 'Save requires a user name'.freeze) if !@unam
    json = Items.generate(@data, 'Config values'.freeze, Config::ValConfig)
    @s3.put_object( bucket: @bck, key: _key(@unam), body: json )
  end # def save()

end # class ICFS::Web::ConfigS3

end # module ICFS::Web
end # module ICFS
