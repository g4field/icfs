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

require_relative 'core'

module ICFS
module Email

##########################################################################
# Receive email user based on FROM: header
#
# @note Only use this in conjunction with some form of email spoofing
#   prevention.
#
class From


  ###############################################
  # New instance
  #
  # @param map [Object] Maps email address to username
  #
  def initialize(map)
    @map = map
  end # def initialize()


  ###############################################
  # Extract the user based on the FROM: email.
  #
  def receive(env)
    email = env[:msg].from.first
    unam = @map[email]
    env[:user] = unam if unam
    return :continue
  end # def receive()


end # class ICFS::Email::From

end # module ICFS::Email
end # module ICFS
