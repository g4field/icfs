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

require 'openssl'
require 'digest/sha2'

require_relative 'rx'

module ICFS
module Email

##########################################################################
# Receive S/MIME email
#
# This processes the most common S/MIME implementation:
#   * Signed: multipart/signed; protocol="application/pkcs7-signature" with
#        application/pkcs7-signature as the second part
#   * Encrypted: application/pkcs7-mime containing eenvelope data
#   * Both: application/pkcs7-mime containing encrypted data, which contains
#        multipart/signed message
#
#  In all cases, it will generate an email containing just the content.  If
#  the message is signed and verifies, it will try a lookup of the DN to
#  determine the user.
#
class RxSmime


  ###############################################
  # New instance
  #
  # @param key [::OpenSSL::PKey] The key for the ICFS gateway
  # @param cert [::OpenSSL::X509::Certificate] the ICFS gateway certificate
  # @param ca [::OpenSSL::X509::Store] Trusted CA certs
  # @param map [Object] Maps DN to user name
  #
  def initialize(key, cert, ca, map)
    @key = key
    @cert = cert
    @ca = ca
    @map = map
  end # end def initialize()


  Fields = [
    "to",
    "cc",
    "message-id",
    "in-reply-to",
    "references",
    "subject",
    "comments",
    "keywords",
    "date",
    "from",
    "sender",
    "reply-to",
  ].freeze


  ###############################################
  #  Process for S/MIME encryption or signatures
  #
  def receive(env)

    # start with the main message
    part = env[:msg]
    replace = false

    # process all PKCS7
    while true

      case part.header[:content_type].string

      # encrypted
      when 'application/pkcs7-mime', 'application/x-pkcs7-mime'

        # decrypt
        enc_raw = part.body.decoded
        enc_p7 = ::OpenSSL::PKCS7.new(enc_raw)
        dec_raw = enc_p7.decrypt(@key, @cert)

        # new part is whatever we decrypted
        part = ::Mail::Part.new(dec_raw)
        replace = true

      # signed
      when 'multipart/signed'

        # check sig
        multi = part.body.parts
        msg = multi[0].raw_source.dup.force_encoding('ASCII-8BIT')
        msg = msg[2..-1] if msg[0,2] == "\r\n" # extra cr/lf
        sig_raw = multi[1].body.decoded
        sig_p7 = ::OpenSSL::PKCS7.new(sig_raw)
        val = sig_p7.verify([], @ca, msg)
        break unless val

        # get cert that signed first
        si = sig_p7.signers.first
        cert = sig_p7.certificates.select do |c|
          (c.issuer == si.issuer) && (c.serial == si.serial)
        end
        break if cert.empty?

        # get user
        unam = @map[cert.first.subject.to_s(::OpenSSL::X509::Name::RFC2253)]
        break unless unam

        # values
        env[:user] = unam
        env[:time] = si.signed_time.to_i

        # new part is body
        part = multi[0]
        replace = true

      # not PKCS7
      else
        break
      end
    end

    return :continue unless replace

    # create new message
    msg = ::Mail::Message.new
    msg.body = part.body.encoded
    oh = env[:msg].header
    hd = msg.header
    Fields.each do |fn|
      fi = oh[fn]
      hd[fn] = fi.value if fi
    end
    part.header.fields.each{|fd| hd[fd.name] = fd.value }

    # Mail acts wierd about parts unless we run it thru text...
    env[:msg] = ::Mail::Message.new(msg.encoded)

    return :continue
  end # def receive()

end # class ICFS::Email::RxSmime

end # module ICFS::Email
end # module ICFS
