
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

require 'net/imap'
require 'mail'

module ICFS
module Email

##########################################################################
# Get email using IMAP
#
class Imap

  ###############################################
  # New instance
  #
  # @param core [Email::Core] The core email processor
  # @param log [Logger] The log
  # @param opts [Hash] configuration options
  # @option opts [String] :address The server address
  # @option opts [Integer] :port The server port
  # @option opts [Boolean] :enable_ssl Use SSL or not
  # @option opts [String] :username The login username
  # @option opts [String] :password The login password
  # @option opts [String] :mailbox The mailbox to read
  # @option opts [Array,String] :keys keys to pass to {::Net::IMAP#uid_search}
  # @option opts [Integer] :idle_time Seconds to wait IDLE before polling
  # @option opts [Integer] :reconnect Seconds after which we can reconnect
  #
  def initialize(core, log, opts={})
    @core = core
    @log = log
    @cfg = {
      :port => 993,
      :enable_ssl => true,
      :keys => 'ALL',
      :idle_time => 60*5,
      :reconnect => 60*15,
    }.merge!(opts)
  end # def initialize()


  ###############################################
  # Handles reconnects when dropped
  #
  def reconnect()

    while true
      start = Time.now
      begin
        fetch()
      rescue EOFError
        if( (Time.now - start) > @cfg[:reconnect] )
          @log.info('IMAP: lost connection, reconnecting')
          next
        else
          @log.error('IMAP: disconnected under the reconnect limit')
          break
        end
      end
    end

  end # def reconnect()


  ###############################################
  # Fetch messages
  #
  def fetch()

    # open & login
    imap = ::Net::IMAP.new(@cfg[:address], @cfg[:port],
        @cfg[:enable_ssl], nil, false)
    imap.login(@cfg[:username], @cfg[:password])
    @log.info('IMAP: open and login')

    # mailbox
    if @cfg[:mailbox]
      imap.select(::Net::IMAP.encode_utf7(@cfg[:mailbox]))
      @log.info('IMAP: mailbox selected: %s' % @cfg[:mailbox])
    else
      @log.error('IMAP: no mailbox specified')
      mbxs = imap.list('', '*')
      @log.info('IMAP: mailbox list: %s' % mbxs.map{|mb| mb.name }.join(', '))
      return
    end

    while true
      # fetch messages
      uids = imap.uid_search(@cfg[:keys])
      @log.debug('IMAP: %d messages found' % uids.size)
      uids.each do |uid|
        fd = imap.uid_fetch(uid, ['RFC822'])[0]
        @log.debug('IMAP: message fetched')
        msg = ::Mail.new(fd.attr['RFC822'])
        @core.receive(msg)
        if @cfg[:delete]
          imap.uid_store(uid, "+FLAGS", [:Deleted])
          @log.debug('IMAP: message deleted')
        end
      end
      if @cfg[:delete]
        imap.expunge
        @log.debug('IMAP: expunged')
      end

      # wait IDLE until new mail
      if @cfg[:idle_time]
        @log.debug('IMAP: starting IDLE')
        imap.idle(@cfg[:idle_time]) do |resp|
          if resp.is_a?(::Net::IMAP::UntaggedResponse) && resp.name == "EXISTS"
            @log.debug('IMAP: new mail, IDLE done')
            imap.idle_done
          end
        end
        @log.debug('IMAP: exited IDLE')

      # or we just run once
      else
        @log.debug('IMAP: fetch completed')
        break
      end
    end

  ensure
    if defined?(imap) && imap && !imap.disconnected?
      imap.disconnect
      @log.info('IMAP: disconnected')
    end
  end # def fetch()


end # class ICFS::Email::Imap

end # module ICFS::Email
end # module ICFS
