#!/usr/bin/env bash
set -Eeuo pipefail

# Build the new image first; ARM64 execution on AMD64 needs registered QEMU.
old_version="${1:-10.2.2}"
target_arch="${2:-amd64}"
case "$old_version" in 3.1.0|10.2.2) ;; *) exit 2 ;; esac
case "$target_arch" in amd64|arm64) ;; *) exit 2 ;; esac
old_image="btcpayserver/woocommerce:${old_version}-amd64"
target_image="${UPGRADE_IMAGE:-woocommerce-update-test:11.1.2-$target_arch}"
test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_id="wc-upgrade-$(date +%s)-$$"
test_network=
test_html=
test_secrets=
test_db=
test_app=

cleanup() {
    local result="$?"
    if [ "$result" -ne 0 ] && [ -n "$test_app" ]; then
        docker logs "$test_app" 2>&1 | tail -n 30 || true
    fi
    if [ -n "$test_app" ]; then docker rm -f "$test_app" >/dev/null; fi
    if [ -n "$test_db" ]; then docker rm -f "$test_db" >/dev/null; fi
    if [ -n "$test_html" ]; then docker volume rm "$test_html" >/dev/null; fi
    if [ -n "$test_secrets" ]; then docker volume rm "$test_secrets" >/dev/null; fi
    if [ -n "$test_network" ]; then docker network rm "$test_network" >/dev/null; fi
}
trap cleanup EXIT

write_secret() {
    docker run --rm --platform linux/amd64 --entrypoint bash \
        --mount "type=volume,src=$test_secrets,dst=/run/test-secrets" \
        "$old_image" -ceu 'printf "%s\n" "$1" > /run/test-secrets/db-password' -- "$1"
}

start_app() {
    test_app="$(docker run --rm -d --platform "$2" --network "$test_network" \
        --mount "type=volume,src=$test_html,dst=/var/www/html" \
        --mount "type=volume,src=$test_secrets,dst=/run/secrets,readonly" \
        --mount "type=bind,src=$test_dir,dst=/upgrade-tests,readonly" \
        --env WOOCOMMERCE_HOST=localhost --env WORDPRESS_DB_HOST=db \
        --env WORDPRESS_DB_USER=wordpress --env WORDPRESS_DB_NAME=wordpress \
        --env WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db-password \
        --env WORDPRESS_TABLE_PREFIX=compat_ \
        --env "WORDPRESS_CONFIG_EXTRA=define('DISABLE_WP_CRON', true); define('AUTOMATIC_UPDATER_DISABLED', true);" \
        "$1")"
    for attempt in {1..45}; do
        if docker exec "$test_app" curl -fsS --max-time 2 -o /dev/null http://localhost/wp-login.php 2>/dev/null; then return; fi
        if [ "$(docker inspect -f '{{.State.Running}}' "$test_app" 2>/dev/null)" != true ]; then break; fi
        sleep 1
    done
    echo 'WordPress did not become ready.' >&2
    return 1
}

stop_app() {
    docker rm -f "$test_app" >/dev/null
    test_app=
}

site_checksum() {
    docker exec "$test_app" bash -ceu '
        find wp-admin wp-includes wp-content/plugins wp-content/themes -type f -print0 | sort -z | xargs -0 sha256sum
        sha256sum index.php .htaccess wp-config.php wp-content/uploads/upgrade-proof.txt
    ' | sha256sum
}

verify_site() {
    docker exec --user www-data "$test_app" wp eval-file /upgrade-tests/verify.php
    test "$(docker exec "$test_app" curl -sS --max-time 30 -o /dev/null -w '%{http_code}' http://localhost/)" = 200
}

test_network="$(docker network create "$test_id")"
test_html="$(docker volume create "$test_id-html")"
test_secrets="$(docker volume create "$test_id-secrets")"
test_db="$(docker run --rm -d --network "$test_network" --network-alias db \
    --tmpfs /var/lib/mysql:rw --env MARIADB_ROOT_PASSWORD=upgrade-test-root \
    --env MARIADB_DATABASE=wordpress --env MARIADB_USER=wordpress \
    --env MARIADB_PASSWORD=initial-test-password mariadb:10.11)"
for attempt in {1..45}; do
    if docker exec "$test_db" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then break; fi
    sleep 1
done
docker exec "$test_db" healthcheck.sh --connect --innodb_initialized
write_secret initial-test-password

echo "Installing the published $old_image with persistent site data..."
start_app "$old_image" linux/amd64
docker exec --user www-data "$test_app" wp core install --url=http://localhost --title=Upgrade-test \
    --admin_user=upgrade-admin --admin_password=temporary-test-password --admin_email=upgrade@example.test --skip-email
docker exec --user www-data "$test_app" wp plugin activate woocommerce btcpay-greenfield-for-woocommerce
docker exec --user www-data "$test_app" wp eval-file /upgrade-tests/seed.php
verify_site
original_checksum="$(site_checksum)"
stop_app

echo "Replacing only the container with $target_image (linux/$target_arch)..."
start_app "$target_image" "linux/$target_arch"
verify_site
test "$(site_checksum)" = "$original_checksum"
echo 'Persistent WordPress, plugins, themes, uploads, and wp-config.php are byte-for-byte unchanged.'
stop_app

echo 'Rotating the database password and recreating the container with the updated Docker secret...'
docker exec "$test_db" mariadb -uroot -pupgrade-test-root \
    --execute="ALTER USER 'wordpress'@'%' IDENTIFIED BY 'rotated-test-password';"
write_secret rotated-test-password
start_app "$target_image" "linux/$target_arch"
verify_site
stop_app
start_app "$target_image" "linux/$target_arch"
verify_site
echo "PASS: $old_version -> 11.1.2 on $target_arch, including secret rotation and restart."
