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
# Basic email processing
#
# This looks for ICFS email gateway instructions, and processes
# attachments.
#
class Basic

  ###############################################
  # Strip regex
  StripRx = /^[^[:graph:]]*([[:graph:]].*[[:graph:]])[^[:graph:]]*$/.freeze

  ###############################################
  # Strip spaces from collected lines
  #
  def _strip(collect)
    collect.map{ |lr|
      ma = StripRx.match(lr) # include wierd UNICODE spaces
      ma ? ma[1] : nil
    }.compact
  end # def _strip()


  ###############################################
  # Fields regex
  FieldRx = /^ICFS ([^:[:blank:]]*)[[:blank:]]*:[[:blank:]]*(.*)[[:blank:]]*$/.freeze


  ###############################################
  # Regex for stat
  StatRx = /^([+\-]?\d+(\.\d*)?)[^[:graph:]]+([[:graph:]].*[[:graph:]])$/.freeze


  ###############################################
  # Look for instructions in the email and process them
  #
  def receive(env)

    # we only work on text/plain version of the email
    txt = env[:msg].text_part
    return :continue if !txt
    lines = txt.decoded.lines

    # User specified values
    collect = nil
    term = nil
    state = nil
    stat_name = nil
    stat_value = nil
    lines.each do |ln|
      # collecting lines
      if collect
        if ln.start_with?(term)
          case state

          when :tags
            tags = _strip(collect)
            env[:tags] = tags unless tags.empty?
            collect = nil

          when :perms
            perms = _strip(collect)
            env[:perms] = perms unless perms.empty?
            collect = nil

          when :stat
            credit = _strip(collect)
            env[:stats] ||= []
            env[:stats] << {
              'name' => stat_name,
              'value' => stat_value,
              'credit' => credit
            }
            collect = nil

          when :content
            cont = collect.map{|lr| lr.delete("\r")}.join('')
            env[:content] = cont unless cont.empty?
            collect = nil

          else
            raise NotImplementedError
          end
        else
          collect << ln
          next
        end
      end

      next unless ma = FieldRx.match(ln)

      fn = ma[1].downcase

      case fn
      when 'case'
        env[:caseid] = ma[2].strip

      when 'title'
        env[:title] = ma[2].strip

      when 'tags'
        collect = []
        state = :tags
        term = 'ICFS'

      when 'perms'
        collect = []
        state = :perms
        term = 'ICFS'

      when 'stat'
        next unless pm = StatRx.match(ma[2].strip)
        stat_name = pm[3]
        stat_value = pm[1].to_f
        collect = []
        state = :stat
        term = 'ICFS'

      when 'content'
        collect = []
        state = :content
        term = ma[2].strip
        term = 'ICFS' if term.empty?
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
