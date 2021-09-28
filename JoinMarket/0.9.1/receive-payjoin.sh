#!/bin/bash

if ! [ -f "${ENV_FILE}" ]; then
    echo "You need to initialize the wallet.
    jm.sh wallet-tool generate
    jm.sh set-wallet <wallet_name> <Password>"
    exit 1
fi

stop.sh
export $(cat "$ENV_FILE" | xargs)
echo -n "${WALLET_PASS}" | python receive-payjoin.py --wallet-password-stdin "${WALLET_NAME}" "$@"
start.sh