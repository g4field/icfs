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

# run minio
# to debug add -e "MINIO_HTTP_TRACE=/dev/stdout" \
docker run -d \
  -v icfs-obj:/data \
  -p "127.0.0.1:9000:9000" \
  -e "MINIO_ACCESS_KEY=minio_key" \
  -e "MINIO_SECRET_KEY=minio_secret" \
  --network icfs \
  --name icfs-minio \
  minio/minio server /data
