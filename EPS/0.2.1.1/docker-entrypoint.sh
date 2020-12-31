#!/bin/bash
set -e

cat <<-EOF > "config.ini"
${EPS_CONFIG}
EOF

if ! [ -f "/data/cert.crt" ] || ! openssl x509 -checkend 86400 -noout -in /data/cert.crt > /dev/null; then
    rm -rf /data/cert.*
    echo "Generating SSL certificates..."
    openssl genrsa -des3 -passout pass:greenbanana -out /data/cert.pass.key 2048
    openssl rsa -passin pass:greenbanana -in /data/cert.pass.key -out /data/cert.key
    rm /data/cert.pass.key
    openssl req -new -key /data/cert.key -out /data/cert.csr -subj "/CN=SATOSHI NAKAMOTO/O=Electrum/ST=Personal/C=SV"
    openssl x509 -req -days 1825 -in /data/cert.csr -signkey /data/cert.key -out /data/cert.crt
fi

# If we don't do this, eps crash
if ! grep -q "\[watch-only-addresses\]" config.ini; then
    echo "[watch-only-addresses]" >> config.ini
    echo "Added dummy [watch-only-addresses] section to config.ini"
fi

if grep -q "\[electrum-server\]" config.ini; then
    CERT_CONFIG="certfile = \/data\/cert.crt\nkeyfile = \/data\/cert.key"
    sed -i "s/\[electrum-server\]/\0\n$CERT_CONFIG/g" config.ini
    echo "Added certificate settings to the [electrum-server] section of config.ini"
else
    echo "[electrum-server]
certfile = /data/cert.crt
keyfile = /data/cert.key
" >> "config.ini"
    echo "Added [electrum-server] section with certificate settings to config.ini"
fi

if [ "$1" != "electrum-personal-server" ]; then
    exec "$@"
fi

if [[ "${READY_FILE}" ]]; then
    echo "Waiting $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

exec "$@" config.ini