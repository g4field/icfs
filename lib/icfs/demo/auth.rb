#
# Investigative Case File System
#
# Copyright 2019 by Graham A. Field
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# frozen_string_literal: true

require 'rack'

module ICFS
module Demo

##########################################################################
# Test authentication - Rack middleware
#
# @deprecated This is a horrible security implementation, DO NOT USE
#   for anything other than testing.
#
class Auth


  ###############################################
  # New instance
  #
  # @param app [Object] The rack app
  # @param api [Object] the ICFS API
  #
  def initialize(app, api)
    @app = app
    @api = api
  end


  ###############################################
  # Handle the calls
  #
  def call(env)

    # login
    if env['PATH_INFO'] == '/login'
      user = env['QUERY_STRING']
      body = 'User set'

      # set the cookie
      rsp = Rack::Response.new( body, 200, {} )
      rsp.set_cookie( 'icfs-user', {
          value: user,
          expires: Time.now + 24*60*60
        })
      return rsp.finish
    end

    # pull the username from the cookie
    cookies = Rack::Request.new(env).cookies
    user = cookies['icfs-user']
    if !user
      return [400, {'Content-Type' => 'text/plain'}, ['Login first']]
    end

    # set up for the call
    @api.user = user
    env['icfs'] = @api
    return @app.call(env)

  rescue ICFS::Error::NotFound, ICFS::Error::Value => err
    return [400, {'Content-Type' => 'text/plain'}, [err.message]]
  end # def call()

end # class ICFS::Demo::Auth

end # module ICFS::Demo

end # module ICFS
