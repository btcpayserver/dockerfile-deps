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
   if [[ -z "$CORELIGHTNING_RPC" ]]; then
      # CLN also not set
      echo "no valid LN implementation configured, can't start LNBits, giving up!"
      #make it start without LN implementation to run i.e. Blink backend
      #exit 1
   else
      if [[ "$$CORELIGHTNING_RPC" ]]; then
         echo "Waiting $CORELIGHTNING_RPC to be created..."
         while [ ! -S "$CORELIGHTNING_RPC" ]; do sleep 1; done
         echo "lightning-rpc created"
      fi
   fi
else
   /wait-for-it.sh lnd_bitcoin:8080 -- echo "LND is up!"
   while true;do
     curl --fail --header "Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000  /data/.lightning/admin.macaroon)" http://lnd_bitcoin:8080/v1/getinfo && break
     echo "lnd returned non 200 response"
     sleep 2
   done
fi

exec poetry run lnbits --port 5000 --host 0.0.0.0