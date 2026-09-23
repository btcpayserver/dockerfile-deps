# WooCommerce 11.1.2

New installations bundle WordPress 7.1.2, PHP 8.3, WooCommerce 11.1.2, and
BTCPay for WooCommerce 2.8.4. Both AMD64 and ARM64 images are provided.

## Existing installations

Keep the existing `/var/www/html` volume, database, and environment/secret
configuration when replacing the container. Existing WordPress, plugin, theme,
and upload files are retained. Updating the image does not update the WordPress
or plugin versions stored in that volume; manage those updates through
WordPress as before.

The entrypoint retains the previous image's behavior: environment variables
and Docker secret files update the existing `wp-config.php`, custom settings
and unspecified authentication salts remain intact, and the application
database is created if missing and the configured user has permission. Legacy
database defaults and Docker-link variables are also retained.

## Compatibility tests

The Build Only workflow runs these tests for both architecture variants:

- `tests/upgrade.sh` installs the published `3.1.0-amd64` or `10.2.2-amd64`
  image, creates a product, order, gateway settings, and an upload, and then
  replaces only the application container. It verifies persistent file
  checksums, application data, plugin versions, custom table prefix,
  authentication salts, database secret rotation, and a second restart.
- `tests/startup.sh` checks a fresh install, delayed database availability,
  automatic database creation, Docker secrets, legacy defaults/link variables,
  multiline configuration values, and public/Tor hostname handling.

The old images seed architecture-independent PHP files and data; the upgraded
container runs on the requested architecture. ARM64 is exercised under QEMU on
AMD64 runners. Tests use disposable databases, volumes, and networks and do not
contact a payment server.

To run locally from the repository root:

```bash
docker build -t woocommerce-update-test:11.1.2-amd64 \
  -f WooCommerce/11.1.2/linuxamd64.Dockerfile WooCommerce/11.1.2
bash WooCommerce/11.1.2/tests/startup.sh amd64
bash WooCommerce/11.1.2/tests/upgrade.sh 3.1.0 amd64
bash WooCommerce/11.1.2/tests/upgrade.sh 10.2.2 amd64
```

For ARM64, build `linuxarm64v8.Dockerfile` with the tag
`woocommerce-update-test:11.1.2-arm64` and use `arm64` as the test argument.
An AMD64 host needs registered ARM64 emulation. Set `UPGRADE_IMAGE` to test a
different locally built image tag.
