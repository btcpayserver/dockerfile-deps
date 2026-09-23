<?php
// Test data only: do not contact a payment server or process a payment.
$product = new WC_Product_Simple();
$product->set_name('Preserved upgrade product');
$product->set_regular_price('12.34');
$product->set_sku('upgrade-proof');
$product->set_status('publish');
$product_id = $product->save();

$order = wc_create_order();
$order->add_product($product, 2);
$order->set_billing_email('upgrade@example.test');
$order->set_payment_method('btcpay_gf');
$order->calculate_totals();
$order->save();

$settings = array('enabled' => 'no', 'title' => 'Preserved Bitcoin gateway', 'upgrade_proof' => 'test-setting');
update_option('woocommerce_btcpay_gf_settings', $settings);
wp_mkdir_p(WP_CONTENT_DIR . '/uploads');
file_put_contents(WP_CONTENT_DIR . '/uploads/upgrade-proof.txt', 'preserved upload');

require_once ABSPATH . 'wp-admin/includes/plugin.php';
$gateways = array_keys(WC()->payment_gateways()->payment_gateways());
sort($gateways);
update_option('woocommerce_upgrade_proof', array(
    'wordpress' => get_bloginfo('version'),
    'woocommerce' => WC_VERSION,
    'btcpay' => get_plugin_data(WP_PLUGIN_DIR . '/btcpay-greenfield-for-woocommerce/btcpay-greenfield-for-woocommerce.php')['Version'],
    'plugins' => get_option('active_plugins'),
    'theme' => get_stylesheet(),
    'product' => $product_id,
    'order' => $order->get_id(),
    'settings' => $settings,
    'gateways' => $gateways,
    'salts' => hash('sha256', AUTH_KEY . SECURE_AUTH_KEY . LOGGED_IN_KEY . NONCE_KEY . AUTH_SALT . SECURE_AUTH_SALT . LOGGED_IN_SALT . NONCE_SALT),
));
echo "Persistent product, order, gateway settings, and upload created.\n";
