#!/usr/bin/env bash
set -Eeuo pipefail

target_arch="${1:-amd64}"
case "$target_arch" in amd64|arm64) ;; *) exit 2 ;; esac
target_image="${UPGRADE_IMAGE:-woocommerce-update-test:11.1.2-$target_arch}"
test_network=
test_gate=
test_db=
cleanup() {
    if [ -n "$test_db" ]; then docker rm -f "$test_db" >/dev/null; fi
    if [ -n "$test_gate" ]; then docker volume rm "$test_gate" >/dev/null; fi
    if [ -n "$test_network" ]; then docker network rm "$test_network" >/dev/null; fi
}
trap cleanup EXIT
test_id="wc-startup-$(date +%s)-$$"
test_network="$(docker network create "$test_id")"
test_gate="$(docker volume create "$test_id-gate")"
# No MARIADB_DATABASE: the WordPress entrypoint must create the application DB.
test_db="$(docker run --rm -d --network "$test_network" --network-alias db --network-alias mysql \
    --mount "type=volume,src=$test_gate,dst=/startup-gate,readonly" \
    --tmpfs /var/lib/mysql:rw --env MARIADB_ROOT_PASSWORD=startup-test-password \
    --entrypoint bash mariadb:10.11 -c 'while [ ! -f /startup-gate/start ]; do sleep 1; done; exec docker-entrypoint.sh mariadbd')"

docker run --rm -i --platform "linux/$target_arch" --network "$test_network" \
    --mount "type=volume,src=$test_gate,dst=/startup-gate" \
    --env WORDPRESS_DB_HOST=db --env 'WORDPRESS_DB_NAME=compat`database' \
    --env WORDPRESS_DB_PASSWORD_FILE=/tmp/db-password \
    --env WORDPRESS_AUTH_KEY=$'first\nsecond' \
    --env "WORDPRESS_CONFIG_EXTRA=define('DISABLE_WP_CRON', true);" \
    "$target_image" bash -se <<'BASH'
set -o pipefail
printf 'startup-test-password\n' > /tmp/db-password
# No WOOCOMMERCE_HOST and no WORDPRESS_DB_USER: preserve the old root default.
docker-entrypoint.sh apache2-foreground -t > /tmp/startup.log 2>&1 &
entrypoint_pid=$!
# Start MariaDB only after observing a retry, independent of runner speed.
for attempt in {1..90}; do
    if grep -q 'Retrying in 3 seconds' /tmp/startup.log; then
        touch /startup-gate/start
        break
    fi
    if ! kill -0 "$entrypoint_pid" 2>/dev/null; then cat /tmp/startup.log; exit 1; fi
    sleep 1
done
test -f /startup-gate/start
wait "$entrypoint_pid"
cat /tmp/startup.log
grep -q 'Retrying in 3 seconds' /tmp/startup.log
test ! -e /etc/apache2/conf-enabled/servername.conf
php -l wp-config.php
php -r 'if (PHP_MAJOR_VERSION !== 8 || PHP_MINOR_VERSION !== 3 || !extension_loaded("soap") || ini_get("upload_max_filesize") !== "100M") { exit(1); }'
test "$(wp --allow-root core version)" = 7.1.2
test "$(wp --allow-root cli version)" = 'WP-CLI 2.12.0'
wp --allow-root core install --url=http://localhost --title=Startup-test --admin_user=startup-admin \
    --admin_password=temporary-test-password --admin_email=startup@example.test --skip-email
wp --allow-root plugin activate woocommerce btcpay-greenfield-for-woocommerce
wp --allow-root eval 'if (AUTH_KEY !== "first\nsecond" || DB_USER !== "root" || DB_CHARSET !== "utf8" || WC_VERSION !== "11.1.2" || BTCPAYSERVER_VERSION !== "2.8.4") { exit(1); }'

if WORDPRESS_DB_PASSWORD=conflicting docker-entrypoint.sh apache2-foreground -t > /tmp/conflict.log 2>&1; then
    echo 'Expected conflicting environment/secret inputs to fail.' >&2
    exit 1
fi
grep -q 'both WORDPRESS_DB_PASSWORD and WORDPRESS_DB_PASSWORD_FILE are set' /tmp/conflict.log

# Non-server commands must not wait for Tor.
WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE=/nonexistent timeout 10 docker-entrypoint.sh wp --allow-root cli version
export WOOCOMMERCE_HOST=shop.example.test
docker-entrypoint.sh apache2-foreground -t
grep -Fxq 'ServerName shop.example.test' /etc/apache2/conf-enabled/servername.conf
touch /tmp/onion-hostname
export WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE=/tmp/onion-hostname
(sleep 1; printf 'upgradetest.onion\n' > /tmp/onion-hostname) &
tor_writer=$!
timeout 30 docker-entrypoint.sh apache2-foreground -t
wait "$tor_writer"
grep -Fxq 'ServerName upgradetest.onion' /etc/apache2/conf-enabled/servername.conf
test "$(wc -l < /etc/apache2/conf-enabled/servername.conf)" -eq 1
unset WOOCOMMERCE_HOST WOOCOMMERCE_HIDDENSERVICE_HOSTNAME_FILE
docker-entrypoint.sh apache2-foreground -t
test ! -e /etc/apache2/conf-enabled/servername.conf
BASH

# Legacy Docker-link environment variables also remain supported.
docker run --rm --platform "linux/$target_arch" --network "$test_network" \
    --env MYSQL_ENV_MYSQL_ROOT_PASSWORD=startup-test-password \
    --env MYSQL_ENV_MYSQL_DATABASE=legacy_link_database \
    "$target_image" apache2-foreground -t
test "$(docker exec "$test_db" mariadb -uroot -pstartup-test-password -N \
    --execute="SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'legacy_link_database';")" = legacy_link_database
echo "PASS: fresh installation, delayed DB, secrets, legacy DB defaults/links, and host/Tor handling on $target_arch."
