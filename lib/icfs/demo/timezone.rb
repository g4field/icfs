#
# Investigative Case File System
#
# Copyright 2019 by Graham A. Field
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#
module ICFS
module Demo

##########################################################################
# Set timezone - Rack middleware
#
# @deprecated This does nothing but set a static timezone.  Do not use for
#   anything other than testing.
#
class Timezone

  # New instance
  def initialize(app, tz)
    @app = app
    @tz = tz.freeze
  end

  # process requests
  def call(env)
    env['icfs.tz'] = @tz
    @app.call(env)
  end

end # class ICFS::Demo::Timezone

end # module ICFS::Demo
end # module ICFS
