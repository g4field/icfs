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

# run redis
docker run -d --rm \
  --network icfs \
  --name icfs-redis \
  redis:alpine
# to run the CLI: docker exec -it icfs-redis redis-cli
