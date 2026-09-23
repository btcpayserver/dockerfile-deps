#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == apache2* ]]; then
    server_name="${WOOCOMMERCE_HOST:-}"

    if [ -n "${WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE:-}" ]; then
        echo "Waiting for $WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE to be created by Tor..."
        while [ ! -s "$WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE" ]; do sleep 1; done
        # Preserve the Tor hostname's precedence over the public hostname.
        server_name="$(head -n 1 "$WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE")"
    fi

    if [ -n "$server_name" ]; then
        printf 'ServerName %s\n' "$server_name" > /etc/apache2/conf-enabled/servername.conf
    else
        rm -f /etc/apache2/conf-enabled/servername.conf
    fi
fi

# Keep WordPress initialization and Docker secrets support in the upstream image.
exec /usr/local/bin/docker-entrypoint.sh "$@"
