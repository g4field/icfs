#!/bin/bash
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

# make certs
../../bin/icfs_demo_ssl_gen.rb

# copy static content
mkdir web
mkdir web/static
mkdir web/static/static
cp ../icfs.css web/static/static/
cp ../icfs.js web/static/static/

# config files
mkdir web/config
mv ca_cert.pem web/config/
mv srv_cert.pem web/config/
mv srv_key.pem web/config/
