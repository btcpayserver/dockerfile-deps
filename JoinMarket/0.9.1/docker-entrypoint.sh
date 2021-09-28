#!/bin/bash
set -e

cd ..
. jmvenv/bin/activate
cd scripts

# First we restore the default cfg as created by wallet-tool.py generate
cp "$DEFAULT_CONFIG" "$CONFIG"
# For every env variable JM_FOO=BAR, replace the default configuration value of 'foo' by 'bar'
while IFS='=' read -r -d '' n v; do
    n="${n,,}" # lowercase
    if [[ "$n" =  jm_* ]]; then
        n="${n:3}" # drop jm_
        sed -i "s/^$n = .*/$n = $v/g" "$CONFIG"
    fi
done < <(env -0)
#####################################

if [[ "${READY_FILE}" ]]; then
    echo "Waiting $READY_FILE to be created..."
    while [ ! -f "$READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

if ! [ -f "${ENV_FILE}" ]; then
    echo "You need to initialize the wallet.
    jm.sh wallet-tool-generate
    jm.sh set-wallet <wallet_name> <Password>"
    exec sleep infinity
fi
export $(cat "$ENV_FILE" | xargs)

: "${JM_YIELD_GENERATOR:=yield-generator-basic.py}"

echo "Using wallet ${WALLET_NAME} with $JM_YIELD_GENERATOR"
LOCKFILE="/root/.joinmarket/wallets/.${WALLET_NAME}.lock"
rm -f /root/.joinmarket/wallets/.${WALLET_NAME}.lock
while true; do
    if [ -f "/tmp/stop" ]; then
        echo "/tmp/stop is present, waiting it to get removed to start again..."
        touch /tmp/stopped
    elif [ -f "$LOCKFILE" ]; then
        echo "$LOCKFILE is present, waiting it to get removed to start again..."
        touch /tmp/stopped
    else
        rm -f /tmp/stopped
        echo -n "${WALLET_PASS}" | python "${JM_YIELD_GENERATOR}" --wallet-password-stdin "${WALLET_NAME}" || true
        touch /tmp/stopped
    fi
    sleep 10
done
