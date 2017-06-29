FROM php:5.4-apache

ENV ADT_DEV_MODE true

RUN pecl install apcu-4.0.11 \
    && echo extension=apcu.so > /usr/local/etc/php/conf.d/apcu.ini

# install git
RUN apt-get -y update && apt-get -y install git

# slim down image
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/man/?? /usr/share/man/??_*

RUN mkdir -p /conf/adt/ && \
    mkdir -p /conf/features/

WORKDIR /var/adt
VOLUME ["/var/adt"]
VOLUME ["/conf"]

CMD php -S 0.0.0.0:80 -c /var/adt/etc/php/cli-server.ini -t /var/adt/var/www/ /var/adt/var/www/router.php
