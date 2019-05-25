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

# run the server
docker run \
  -v icfs-dev:/var/lib/icfs \
  -v $1:/icfs \
  -p "127.0.0.1:80:8080" \
  --network icfs \
  -it --rm icfs-wrk
