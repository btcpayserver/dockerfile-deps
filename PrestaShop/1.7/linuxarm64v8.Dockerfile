# Base image uses PHP which supports linux/arm64/v8
FROM prestashop/prestashop:1.7

ENV BTCPAY_PLUGIN_VERSION 0.1.0

ENV PS_ROOT '/var/www/html'
ENV PS_INSTALL_FILE 'src/PrestaShopBundle/Install/Install.php'

# Add the BTCPay module to the modules directory
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip wget \
    && wget https://github.com/btcpayserver/prestashop-plugin/releases/download/v${BTCPAY_PLUGIN_VERSION}/btcpay.zip -O /tmp/temp.zip \
    && cd $PS_ROOT/modules && unzip /tmp/temp.zip && rm /tmp/temp.zip \
    && rm -rf /var/lib/apt/lists/*

# Add the BTCPay module to the preinstalled list after default 'Welcome' module
RUN sed -i "/'welcome',/a 'btcpay'," "$PS_ROOT/$PS_INSTALL_FILE"

VOLUME ["/var/www/html"]
