#!/bin/bash
set -e

pushd . > /dev/null
cd /src
. jmvenv/bin/activate
popd > /dev/null

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
    COMMAND="$1"
    shift 1
    export $(cat "$ENV_FILE" | xargs)
    echo -n "${WALLET_PASS}" | python "$COMMAND" --wallet-password-stdin "${WALLET_NAME}" "$@"
fi



