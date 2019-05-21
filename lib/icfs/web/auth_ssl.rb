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
module Web

##########################################################################
# Authtication using SSL client certificates - Rack Middleware
#
class AuthSsl

  ###############################################
  # New instance
  #
  # @param app [Object] The rack app
  # @param map [Object] Maps DN to user name
  # @param api [ICFS::Api] the Api
  #
  def initialize(app, map, api)
    @app = app
    @map = map
    @api = api
  end


  ###############################################
  # Handle requests
  #
  # Expects SSL_CLIENT_VERIFY to be set to SUCCESS and SSL_CLIENT_S_DN
  # to contain the client subject DN
  #
  def call(env)

    # check if verified
    unless env['SSL_CLIENT_VERIFY'] == 'SUCCESS'
      return [
        400,
        {'Content-Type' => 'text/plain'.freeze},
        ['Client certificate required.'.freeze]
      ]
    end

    # lookup
    user = @map[env['SSL_CLIENT_S_DN']]
    if user.nil?
      return [
        400,
        {'Content-Type' => 'text/plain'.freeze},
        ['%s: No User' % env['SSL_CLIENT_S_DN']]
      ]
    end

    # pass to app
    begin
      @api.user = user
    rescue Error::NotFound, Error::Value => err
      return [
        400,
        {'Content-Type' => 'text/plain'.freeze},
        ['%s: %s' % [err.message, env['SSL_CLIENT_S_DN']]]
      ]
    end
    env['icfs'] = @api
    return @app.call(env)
  end # def call()


end # class ICFS::Web::AuthSsl

end # module ICFS::Web

end # module ICFS
