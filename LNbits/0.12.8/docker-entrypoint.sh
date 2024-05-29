#!/bin/bash
set -e

if [[ "${LND_READY_FILE}" ]]; then
    echo "Waiting $LND_READY_FILE to be created..."
    while [ ! -f "$LND_READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

if [[ "${LIGHTNINGD_READY_FILE}" ]]; then
    echo "Waiting $LIGHTNINGD_READY_FILE to be created..."
    while [ ! -f "$LIGHTNINGD_READY_FILE" ]; do sleep 1; done
    echo "The chain is fully synched"
fi

# wait for LND or CLN

if [[ -z "$LND_REST_ENDPOINT" ]]; then
   # $var is empty, do what you want
   # check for CLN
   if [[ -z "$CORELIGHTNING_REST_URL" ]]; then
      # CLN also not set
      echo "no valid LN implementation configured, can't start LNBits, giving up!"
      exit 1
   else
      ./wait-for-it.sh clightning_bitcoin_rest:3001 -- echo "CLN is up!"
else
   ./wait-for-it.sh lnd_bitcoin:8080 -- echo "LND is up!"
fi

exec poetry run lnbits --port 5000 --host 0.0.0.0