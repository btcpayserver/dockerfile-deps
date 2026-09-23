<?php
global $wpdb;
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$expected = get_option('woocommerce_upgrade_proof');
if (!$expected) {
    throw new RuntimeException('Existing site data was not found.');
}
$checks = array(
    get_bloginfo('version') === $expected['wordpress'],
    WC_VERSION === $expected['woocommerce'],
    get_plugin_data(WP_PLUGIN_DIR . '/btcpay-greenfield-for-woocommerce/btcpay-greenfield-for-woocommerce.php')['Version'] === $expected['btcpay'],
    get_option('active_plugins') === $expected['plugins'],
    get_stylesheet() === $expected['theme'],
    $wpdb->prefix === 'compat_',
    get_user_by('login', 'upgrade-admin') !== false,
    get_option('woocommerce_btcpay_gf_settings') === $expected['settings'],
    file_get_contents(WP_CONTENT_DIR . '/uploads/upgrade-proof.txt') === 'preserved upload',
    defined('DISABLE_WP_CRON') && DISABLE_WP_CRON,
    hash('sha256', AUTH_KEY . SECURE_AUTH_KEY . LOGGED_IN_KEY . NONCE_KEY . AUTH_SALT . SECURE_AUTH_SALT . LOGGED_IN_SALT . NONCE_SALT) === $expected['salts'],
);
$product = wc_get_product($expected['product']);
$order = wc_get_order($expected['order']);
$checks[] = $product && $product->get_sku() === 'upgrade-proof' && $product->get_price() === '12.34';
$checks[] = $order && $order->get_billing_email() === 'upgrade@example.test' && $order->get_payment_method() === 'btcpay_gf' && $order->get_total() === '24.68';
$gateways = array_keys(WC()->payment_gateways()->payment_gateways());
sort($gateways);
$checks[] = count($gateways) > 0 && $gateways === $expected['gateways'];
foreach ($checks as $index => $passed) {
    if (!$passed) {
        throw new RuntimeException('Upgrade preservation check failed: ' . $index);
    }
}
printf("Preserved WordPress %s, WooCommerce %s, BTCPay %s, configuration, and shop data.\n", $expected['wordpress'], $expected['woocommerce'], $expected['btcpay']);
