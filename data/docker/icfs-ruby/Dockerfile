FROM alpine

RUN apk update && apk upgrade && \
    apk add ruby fcgi ruby-json tzdata && \
    apk --update add --virtual build-deps ruby-dev build-base fcgi-dev && \
    gem install -N rack faraday fcgi && \
    apk del build-deps && \
    rm -rf /var/cache/apk/*

COPY ./icfs-0.1.1.gem /icfs.gem

RUN gem install -N --local /icfs.gem && rm /icfs.gem
