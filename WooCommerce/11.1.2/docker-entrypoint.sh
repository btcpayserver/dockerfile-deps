#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == apache2* ]]; then
    rm -f /etc/apache2/conf-enabled/servername.conf
    if [ -n "${WOOCOMMERCE_HOST:-}" ]; then
        printf 'ServerName %s\n' "$WOOCOMMERCE_HOST" > /etc/apache2/conf-enabled/servername.conf
    fi

    if [ -n "${WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE:-}" ]; then
        echo "Waiting for $WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE to be created by Tor..."
        while [ ! -s "$WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE" ]; do sleep 1; done
        hiddenservice_onion="$(head -n 1 "$WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE")"
        printf 'ServerName %s\n' "$hiddenservice_onion" >> /etc/apache2/conf-enabled/servername.conf
    fi
fi

# Keep WordPress initialization and Docker secrets support in the upstream image.
exec /usr/local/bin/docker-entrypoint.sh "$@"
