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

require_relative 'rx'

module ICFS
module Email

##########################################################################
# Receive core processing
#
# This looks for ICFS email gateway instructions, and processes
# attachments.
#
class RxCore


  ###############################################
  # Fields regex
  FieldRx = /^ICFS ([^:[:blank:]]*)[[:blank:]]*:[[:blank:]]*(.*)[[:blank:]]*$/.freeze


  ###############################################
  # Look for instructions in the email and process them
  #
  def receive(env)

    # we only work on text/plain version of the email
    txt = env[:msg].text_part
    return :continue if !txt
    lines = txt.decoded.lines

    # User specified values
    lines.each do |ln|
      next unless ma = FieldRx.match(ln)

      fn = ma[1].downcase
      val = ma[2].strip

      case fn
      when 'case'
        env[:caseid] = val
      when 'title'
        env[:title] = val
      end

    end

    # time defaults to message date
    unless env[:time]
      env[:time] = env[:msg].date.to_time.to_i
    end

    # title defaults to subject if okay
    unless env[:title]
      # check the subject time
      title = env[:msg].subject
      err = Validate.check(title, Items::FieldTitle)
      env[:title] = title unless err
    end

    # save the edited email defaults to yes
    unless env.key?(:save_msg)
      env[:save_msg] = true
    end

    # save the raw email defaults to no
    unless env.key?(:save_raw)
      env[:save_raw] = false
    end

    # save attachments as files
    cnt = 0
    env[:msg].attachments.each do |att|
      type = att.header[:content_disposition].disposition_type
      next if type == 'inline'
      cnt += 1
      name = att.filename
      if !name
        ext = MIME::Types[att.content_type].first.extensions.first
        name = 'unnamed_%d.%s' % [cnt, ext]
      end
      env[:files] << { name: name, content: att.decoded }
    end

    return :continue
  end # def receive()


end # class ICFS::Email::RxCore

end # module ICFS::Email
end # module ICFS
