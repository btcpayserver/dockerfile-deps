#!/bin/sh
set -e

mkdir -p "$(dirname $TOR_CONFIG)"
mkdir -p "$TOR_DATA"
mkdir -p "/etc/torrc.d"

cat <<-EOF > "$TOR_CONFIG"
ControlPort 0.0.0.0:9051
SOCKSPort 0.0.0.0:9050
${TOR_EXTRA_ARGS}
%include /etc/torrc.d/
EOF

if ! [ -z "${TOR_PASSWORD}" ]; then
    TOR_PASSWORD_HASH="$(gosu tor tor --hash-password "$TOR_PASSWORD")"
    echo "HashedControlPassword $TOR_PASSWORD_HASH" >> "$TOR_CONFIG"
    echo "'HashedControlPassword $TOR_PASSWORD_HASH' added to tor config"
fi

chown tor:tor "$TOR_CONFIG"
chown -R tor "$TOR_DATA"

exec gosu tor "$@"
