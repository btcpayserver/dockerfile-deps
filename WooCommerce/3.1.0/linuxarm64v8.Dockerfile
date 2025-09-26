FROM --platform=linux/arm64 wordpress:6.0.2-php8.0

ENV WOOCOMMERCE_VERSION 6.9.4
ENV BTCPAY_PLUGIN_VERSION 1.1.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip wget \
    && wget https://downloads.wordpress.org/plugin/woocommerce.$WOOCOMMERCE_VERSION.zip -O /tmp/temp.zip \
    && wget https://downloads.wordpress.org/plugin/btcpay-greenfield-for-woocommerce.$BTCPAY_PLUGIN_VERSION.zip -O /tmp/temp2.zip \
    && cd /usr/src/wordpress/wp-content/plugins \
    && unzip /tmp/temp.zip \
    && unzip /tmp/temp2.zip \
    && rm /tmp/temp.zip \
    && rm /tmp/temp2.zip \
    && rm -rf /var/lib/apt/lists/*

# Install the gmp, mcrypt and soap extensions
RUN apt-get update -y
RUN apt-get install -y libxml2-dev
RUN docker-php-ext-install soap

# Download WordPress CLI
RUN curl -L "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" > /usr/bin/wp && chmod +x /usr/bin/wp

RUN { \
  echo 'file_uploads = On'; \
  echo 'post_max_size=100M'; \
  echo 'upload_max_filesize=100M'; \
} > /usr/local/etc/php/conf.d/uploads.ini

COPY docker-entrypoint.sh /usr/local/bin/
VOLUME ["/var/www/html"]
