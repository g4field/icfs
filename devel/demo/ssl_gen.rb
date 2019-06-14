#!/usr/bin/env ruby
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

require 'openssl'
require 'yaml'

# read the configuration
cfg = YAML.load(File.read(ARGV[0]))


serial = Time.now.to_i

# make a CA cert
ca_key = OpenSSL::PKey::RSA.new 2048
ca_cert = OpenSSL::X509::Certificate.new
ca_cert.version = 2
ca_cert.serial = serial
ca_cert.subject = OpenSSL::X509::Name.parse(cfg['ca']['cn'])
ca_cert.issuer = ca_cert.subject
ca_cert.public_key = ca_key.public_key
ca_cert.not_before = Time.now
ca_cert.not_after = ca_cert.not_before + (30 * 24 * 60 * 60) # 30 days
ef = OpenSSL::X509::ExtensionFactory.new
ef.subject_certificate = ca_cert
ef.issuer_certificate = ca_cert
ca_cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
ca_cert.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
ca_cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
ca_cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
ca_cert.sign(ca_key, OpenSSL::Digest::SHA256.new)

# save CA cert
File.open("ca_cert.pem", "wb"){|fi| fi.write ca_cert.to_pem }


# make a server cert & key
srv_key = OpenSSL::PKey::RSA.new 2048
srv_cert = OpenSSL::X509::Certificate.new
srv_cert.version = 2
srv_cert.serial = serial + 1
srv_cert.subject = OpenSSL::X509::Name.parse('/OU=org/OU=example/OU=Test Server/CN=localhost')
srv_cert.issuer = ca_cert.subject
srv_cert.public_key = srv_key.public_key
srv_cert.not_before = Time.now
srv_cert.not_after = srv_cert.not_before + (30 * 24 * 60 * 60) # 30 days
ef = OpenSSL::X509::ExtensionFactory.new
ef.subject_certificate = srv_cert
ef.issuer_certificate = ca_cert
srv_cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
srv_cert.add_extension(ef.create_extension("keyUsage", "keyEncipherment,dataEncipherment,digitalSignature"))
srv_cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
srv_cert.add_extension(ef.create_extension("subjectAltName", "email:%s" % cfg['server']['email'], false))
srv_cert.sign(ca_key, OpenSSL::Digest::SHA256.new)

# save server cert & key
File.open("srv_cert.pem", "wb"){|fi| fi.write srv_cert.to_pem }
File.open("srv_key.pem", "wb"){|fi| fi.write srv_key.to_pem }

# make client certs with key included
cnt = 0
cfg['clients'].each do |cc|
  cnt += 1
  clt_key = OpenSSL::PKey::RSA.new 2048
  clt_cert = OpenSSL::X509::Certificate.new
  clt_cert.version = 2
  clt_cert.serial = serial + 2 + cnt
  clt_cert.subject = OpenSSL::X509::Name.parse(cc['cn'])
  clt_cert.issuer = ca_cert.subject
  clt_cert.public_key = clt_key.public_key
  clt_cert.not_before = Time.now
  clt_cert.not_after = clt_cert.not_before + (30 * 24 * 60 * 60) # 30 days
  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = clt_cert
  ef.issuer_certificate = ca_cert
  clt_cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
  clt_cert.add_extension(ef.create_extension("keyUsage", "keyEncipherment,dataEncipherment,digitalSignature"))
  clt_cert.add_extension(ef.create_extension("subjectAltName", "email:%s" % cc['email'], false))
  clt_cert.sign(ca_key, OpenSSL::Digest::SHA256.new)

  # pkcs12
  clt_pkcs12 = OpenSSL::PKCS12.create('demo', 'client-%d' % cnt, clt_key, clt_cert)

  # save cert w/key
  File.open('clt_%d.pfx' % cnt, 'wb'){|fi| fi.write clt_pkcs12.to_der }
end
