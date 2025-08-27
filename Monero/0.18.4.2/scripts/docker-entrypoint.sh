#!/bin/bash
set -e

# Set permissions for directories
chown -R monero "$MONERO_DATA"
chown -R monero:monero "$MONERO_WALLET"
ln -sfn "$MONERO_DATA" /home/monero/.bitmonero
chown -h monero:monero /home/monero/.bitmonero

gosu monero "$@"
