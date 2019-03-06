#!/bin/sh
set -e

cat <<-EOF > "$TOR_CONFIG"
ControlPort 0.0.0.0:9051
CookieAuthentication 1
${TOR_EXTRA_ARGS}
EOF
chown tor:tor "$TOR_CONFIG"

exec gosu tor "$@"
