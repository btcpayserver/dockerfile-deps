#!/bin/bash
set -e

cd ..
. jmvenv/bin/activate
cd scripts

if [[ "$1" != "unlockwallet" ]]; then
    exec "$@"
else
    shift 1
    if ! [ -f "${ENV_FILE}" ]; then
        echo "You need to initialize the wallet.
        jm.sh wallet-tool-generate
        jm.sh set-wallet <wallet_name> <Password>"
        exit 1
    fi
    export $(cat "$ENV_FILE" | xargs)
    echo -n "${WALLET_PASS}" | python "$@" --wallet-password-stdin "${WALLET_NAME}"
fi



