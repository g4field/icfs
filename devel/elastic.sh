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

# run elasticsearch
docker run -d \
  -e "discovery.type=single-node" \
  -v icfs-es:/usr/share/elasticsearch/data \
  --network icfs \
  --name icfs-elastic \
  docker.elastic.co/elasticsearch/elasticsearch:6.7.2
