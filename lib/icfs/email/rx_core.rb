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
  # Valid ICFS email gateway instructions
  ValFields = {
    method: :hash,
    optional: {
      'case' => Items::FieldCaseid,
      'title' => Items::FieldTitle,
      'tags' => {
        method: :array,
        min: 1,
        check: Items::FieldTag
      }.freeze,
      'perms' => {
        method: :array,
        min: 1,
        check: Items::FieldPermAny,
      }.freeze,
    }.freeze,
    others: false
  }.freeze


  ###############################################
  # Begin boundary
  BoundaryBegin = '---ICFS BEGIN---'.freeze


  ###############################################
  # Content boundary
  BoundaryContent = '---ICFS CONTENT---'.freeze


  ###############################################
  # End boundary
  BoundaryEnd = '---ICFS END---'.freeze


  ###############################################
  # Look for instructions in the email and process them
  #
  def receive(env)

    # we only work on text/plain version of the email
    txt = env[:msg].text_part
    return :continue if !txt
    lines = txt.body.decoded.lines

    # scan for the prefix
    cnt = 0
    while ln = lines[cnt]
      cnt += 1
      break if ln.strip == BoundaryBegin
    end
    return :continue if !ln

    # copy YAML until Content or End boundary
    yml = []
    do_content = false
    while ln = lines[cnt]
      cnt += 1

      case ln.strip
      when BoundaryContent
        do_content = true
        break
      when BoundaryEnd
        do_content = false
        break
      else
        yml << ln
      end
    end
    return :continue if !ln
    yml = yml.join(''.freeze)

    # copy content until End boundary
    cont = []
    if do_content
      while ln = lines[cnt]
        cnt += 1
        break if ln.strip == BoundaryEnd
        cont << ln
      end
      return :continue if !ln
    end
    cont = cont.join(''.freeze)

    # parse YAML
    begin
      fields = YAML.safe_load(yml)
    rescue
      return :continue
    end
    err = Validate.check(fields, ValFields)
    return :continue if err

    # caseid, tags, perms
    env[:caseid] = fields['case'] if fields['case']
    env[:tags] = fields['tags'] if fields['tags']
    env[:perms] = fields['perms'] if fields['perms']
    env[:content] = cont unless cont.empty?

    # time
    env[:time] = env[:msg].date.to_time.to_i

    # title specified
    if fields['title']
      env[:title] = fields['title']

    # valid subject line
    else
      # check the subject time
      title = env[:msg].subject
      err = Validate.check(title, Items::FieldTitle)
      env[:title] = title unless err
    end

    # add all attachments as files
    cnt = 0
    env[:msg].attachments.each do |att|
      type = att.header[:content_disposition].disposition_type
      next if type == 'inline'.freeze
      cnt += 1
      name = att.filename
      if !name
        ext = MIME::Types[att.content_type].first.extensions.first
        name = 'unnamed_%d.%s'.freeze % [cnt, ext]
      end
      env[:files] << { name: name, content: att.decoded }
    end
    env[:save_msg] = true

    return :continue
  end # def receive()


end # class ICFS::Email::RxCore

end # module ICFS::Email
end # module ICFS
