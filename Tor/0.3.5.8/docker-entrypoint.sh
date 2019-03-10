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
# ensure correct ownership and linking of data directory
# we do not update group ownership here, in case users want to mount
# a host directory and still retain access to it
chown -R tor "$TOR_DATA"
ln -sfn "$TOR_DATA" /home/tor/.tor
chown -h tor:tor /home/tor/.tor

exec gosu tor "$@"
