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
FROM alpine

RUN apk update && apk upgrade && \
    apk add ruby fcgi ruby-json tzdata && \
    apk --update add --virtual build-deps ruby-dev build-base fcgi-dev && \
    gem install -N rack faraday fcgi && \
    apk del build-deps && \
    rm -rf /var/cache/apk/*

COPY ./icfs-0.1.1.gem /icfs.gem

RUN gem install -N --local /icfs.gem && rm /icfs.gem
