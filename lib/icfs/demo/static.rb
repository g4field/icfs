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

#
module ICFS


##########################################################################
# Demonstration only files
module Demo

##########################################################################
# Serve static files - Rack middleware
#
# @deprecated This is a horrible implementation, DO NOT USE
#   for anything other than testing.
#
class Static

  ###############################################
  # New instance
  #
  # @param stat [Hash] maps path to Hash with :path and :mime
  # @param app [Object] the next rack app
  #
  def initialize(app, stat)
    @stat = stat
    @app = app
  end

  # Process requests
  def call(env)

    # see if we have a static file to serve
    st = @stat[env['PATH_INFO']]
    if st
      cont = File.read(st['path'])
      head = {
        'Content-Type' => st['mime'],
        'Content-Length' => cont.bytesize.to_s
      }
      return [200, head, [cont]]
    end

    return @app.call(env)

  end

end # class ICFS::Demo::Static

end # module ICFS::Demo
end # module ICFS
