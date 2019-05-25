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

FROM alpine:latest

# install software
RUN apk update && \
    apk upgrade && \
    apk --update add ruby fcgi ruby-json tzdata vim curl git bash && \
    apk --update add --virtual build-deps ruby-dev build-base fcgi-dev && \
    gem install -N rack webrick etc faraday yard aws-sdk-s3 && \
    apk del build-deps && \
    rm -rf /var/cache/apk/*

# add user
RUN addgroup -S icfsgrp && \
    adduser -S icfsusr -G icfsgrp

USER icfsusr
