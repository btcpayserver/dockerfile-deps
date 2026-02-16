#!/bin/bash
set -e

# Set permissions for directories
chown -R beldex "$BELDEX_DATA"
chown -R beldex:beldex "$BELDEX_WALLET"
ln -sfn "$BELDEX_DATA" /home/beldex/.beldex
chown -h beldex:beldex /home/beldex/.beldex

gosu beldex "$@"
