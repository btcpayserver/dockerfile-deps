# WooCommerce 11.1.2

New installations bundle WordPress 7.1.2, PHP 8.3, WooCommerce 11.1.2, and
BTCPay for WooCommerce 2.8.4. Both AMD64 and ARM64 images are provided.

## Existing installations

Keep the existing `/var/www/html` volume, database, and environment/secret
configuration when replacing the container. Existing WordPress, plugin, theme,
and upload files are retained. Updating the image does not update the WordPress
or plugin versions stored in that volume; manage those updates through
WordPress as before.

Environment variables and Docker secrets continue to update `wp-config.php`.
Custom settings, unspecified authentication salts, legacy database defaults,
and Docker-link variables are preserved. A missing database is created when
the configured database user has permission.
