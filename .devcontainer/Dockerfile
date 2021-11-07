FROM alpine:latest

RUN apk update \
    && apk add lighttpd \
    && apk add git \
    && apk add sqlite3 \
    && rm -rf /var/cache/apk/*

ADD htdocs /var/www/localhost/htdocs

CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]