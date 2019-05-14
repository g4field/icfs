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
# Shared Elasticsearch methods
#
module Elastic

  private

  ###############################################
  # Read an item
  #
  # @param ix [Symbol] the index to read
  # @param id [String] the id to read
  #
  # @return [String] JSON encoded object
  #
  def _read(ix, id)
    url = '%s/_doc/%s/_source'.freeze % [ @map[ix], CGI.escape(id)]
    resp = @es.run_request(:get, url, ''.freeze, {})
    if resp.status == 404
      return nil
    elsif !resp.success?
      raise('Elasticsearch read failed'.freeze)
    end
    return resp.body
  end # def _read()


  ###############################################
  # Write an item
  #
  # @param ix [Symbol] the index to write
  # @param id [String] the id to write
  # @param item [String] JSON encoded object to write
  #
  def _write(ix, id, item)
    url = '%s/_doc/%s'.freeze % [ @map[ix], CGI.escape(id)]
    head = {'Content-Type'.freeze => 'application/json'.freeze}.freeze
    resp = @es.run_request(:put, url, item, head)
    if !resp.success?
      raise('Elasticsearch index failed'.freeze)
    end
  end # def _write()


  public


  ###############################################
  # Create ES indices
  # @param maps [Hash] symbol to Elasticsearch mapping
  #
  def create(maps)
    head = {'Content-Type'.freeze => 'application/json'.freeze}.freeze
    maps.each do |ix, map|
      url = @map[ix]
      resp = @es.run_request(:put, url, map, head)
      if !resp.success?
        puts 'URL: %s' % url
        puts map
        puts resp.body
        raise('Elasticsearch index create failed: %s'.freeze % ix.to_s)
      end
    end
  end # def create()


end # module ICFS::Elastic

end # module ICFS
