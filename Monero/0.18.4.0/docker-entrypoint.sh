#!/bin/bash
set -e

# Set permissions for directories
chown -R monero "$MONERO_DATA"
chown -R monero "$MONERO_WALLET"

gosu monero "$@"