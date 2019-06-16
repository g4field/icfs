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
require 'tempfile'

module ICFS

##########################################################################
# Permanent store for items using AWS S3
#
class StoreS3 < Store


  ###############################################
  # New store
  #
  # @param client [Aws::S3::Client] The configured S3 client
  # @param bucket [String] The bucket name
  # @param prefix [String] Prefix to use for object keys
  #
  def initialize(client, bucket, prefix=nil)
    @s3 = client
    @bck = bucket
    @base = prefix || ''
  end # def initialize()


  ###############################################
  # (see Store#file_read)
  #
  def file_read(cid, enum, lnum, fnum)
    tmp = tempfile
    key = _file(cid, enum, lnum, fnum)
    @s3.get_object( bucket: @bck, key: key, response_target: tmp)
    tmp.rewind
    return tmp
  rescue Aws::S3::Errors::NoSuchKey
    return nil
  end


  ###############################################
  # (see Store#file_write)
  #
  def file_write(cid, enum, lnum, fnum, tmpf)
    key = _file(cid, enum, lnum, fnum)
    tmpf.rewind
    @s3.put_object( bucket: @bck, key: key, body: tmpf )

    if tmpf.respond_to?( :close! )
      tmpf.close!
    else
      tmpf.close
    end
  end


  ###############################################
  # (see Store#file_size)
  def file_size(cid, enum, lnum, fnum)
    key = _file(cid, enum, lnum, fnum)
    resp = @s3.head_object( bucket: @bck, key: key )
    return resp.content_length
  rescue Aws::S3::Errors::NotFound
    return nil
  end


  ###############################################
  # (see Store#tempfile)
  #
  def tempfile
    Tempfile.new('tmp', encoding: 'ascii-8bit')
  end


  private


  ###############################################
  # (see Store#_read)
  #
  def _read(path)
    @s3.get_object( bucket: @bck, key: path).body.read
  rescue Aws::S3::Errors::NoSuchKey
    return nil
  end # def _read()


  ###############################################
  # (see Store#_write)
  #
  def _write(path, item)
    @s3.put_object( bucket: @bck, key: path, body: item )
  end

end # class ICFS::Store

end # module ICFS
