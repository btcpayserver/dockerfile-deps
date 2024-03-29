#!/bin/bash
set -e

if [[ "$1" == "dogecoin-cli" || "$1" == "dogecoin-tx" || "$1" == "dogecoind" || "$1" == "test_dogecoin" ]]; then
	mkdir -p "$DOGECOIN_DATA"

	CONFIG_PREFIX=""
    if [[ "${BITCOIN_NETWORK}" == "regtest" ]]; then
        CONFIG_PREFIX=$'regtest=1\n'
    fi
    if [[ "${BITCOIN_NETWORK}" == "testnet" ]]; then
        CONFIG_PREFIX=$'testnet=1\n'
    fi
    if [[ "${BITCOIN_NETWORK}" == "mainnet" ]]; then
        CONFIG_PREFIX=$'mainnet=1\n'
    fi

	cat <<-EOF > "$DOGECOIN_DATA/dogecoin.conf"
	${CONFIG_PREFIX}
	printtoconsole=1
	rpcallowip=::/0
	${DOGECOIN_EXTRA_ARGS}
	EOF
	chown dogecoin:dogecoin "$DOGECOIN_DATA/dogecoin.conf"

	# ensure correct ownership and linking of data directory
	# we do not update group ownership here, in case users want to mount
	# a host directory and still retain access to it
	chown -R dogecoin "$DOGECOIN_DATA"
	ln -sfn "$DOGECOIN_DATA" /home/dogecoin/.dogecoin
	chown -h dogecoin:dogecoin /home/dogecoin/.dogecoin

	exec gosu dogecoin "$@"
else
	exec "$@"
fi