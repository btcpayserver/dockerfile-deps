#!/bin/sh
set -e

mkdir -p "$TOR_DATA"

cat <<-EOF > "$TOR_CONFIG"
ControlPort 0.0.0.0:9051
SOCKSPort 0.0.0.0:9050
CookieAuthentication 1
${TOR_EXTRA_ARGS}
EOF

chown tor:tor "$TOR_CONFIG"
chown -R tor "$TOR_DATA"

exec gosu tor "$@"
