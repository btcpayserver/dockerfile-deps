FROM wordpress:7.1.2-php8.3-apache

ENV WOOCOMMERCE_VERSION=11.1.2
ENV BTCPAY_PLUGIN_VERSION=2.8.4
ENV WP_CLI_VERSION=2.12.0

RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends unzip libxml2-dev \
    && docker-php-ext-install soap \
    && curl -fL "https://downloads.wordpress.org/plugin/woocommerce.${WOOCOMMERCE_VERSION}.zip" -o /tmp/woocommerce.zip \
    && curl -fL "https://downloads.wordpress.org/plugin/btcpay-greenfield-for-woocommerce.${BTCPAY_PLUGIN_VERSION}.zip" -o /tmp/btcpay.zip \
    && echo '9de9350a1cf5671b9960afb3151f40f7980e223217a441bf2ea5921b5fce8e9e  /tmp/woocommerce.zip' | sha256sum -c - \
    && echo 'dcdcd0d4bed391ea6a338318861291b69468e62a0e648ab4c63e5f262f9bc2db  /tmp/btcpay.zip' | sha256sum -c - \
    && unzip -q /tmp/woocommerce.zip -d /usr/src/wordpress/wp-content/plugins \
    && unzip -q /tmp/btcpay.zip -d /usr/src/wordpress/wp-content/plugins \
    && chown -R www-data:www-data /usr/src/wordpress/wp-content/plugins \
    && rm /tmp/woocommerce.zip /tmp/btcpay.zip \
    && rm -rf /var/lib/apt/lists/*

# Pin WP-CLI and verify the checksum published with its release.
RUN curl -fL "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" -o /usr/local/bin/wp \
    && echo 'ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c  /usr/local/bin/wp' | sha256sum -c - \
    && chmod +x /usr/local/bin/wp

RUN { \
  echo 'file_uploads = On'; \
  echo 'post_max_size=100M'; \
  echo 'upload_max_filesize=100M'; \
} > /usr/local/etc/php/conf.d/uploads.ini

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
VOLUME ["/var/www/html"]
