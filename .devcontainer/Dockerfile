FROM alpine:latest

RUN apk update \
    && apk add lighttpd \
    && apk add git \
    && apk add sqlite \
    && rm -rf /var/cache/apk/* \
    && lighttpd -D -f /etc/lighttpd/lighttpd.conf

ADD htdocs /var/www/localhost/htdocs