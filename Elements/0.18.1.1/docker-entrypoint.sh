#!/bin/bash
set -e

if [[ "$1" == "elements-cli" || "$1" == "elements-tx" || "$1" == "elementsd" || "$1" == "test_elements" ]]; then
	mkdir -p "$ELEMENTS_DATA"

	CONFIG_PREFIX=""
	CHAIN="$ELEMENTS_CHAIN"
	NL=$'\n'
	if [[ "$CHAIN" ]]; then
		CONFIG_PREFIX="chain=$CHAIN\n[$CHAIN]"
	elif [[ "${ELEMENTS_NETWORK}" == "regtest" ]]; then
		CHAIN="${ELEMENTS_REGTEST_CHAIN:-regtest}"
	elif [[ "${ELEMENTS_NETWORK}" == "testnet" ]]; then
		CHAIN="${ELEMENTS_TESTNET_CHAIN:-testnet}"
	elif [[ "${ELEMENTS_NETWORK}" == "mainnet" ]]; then
		CHAIN="${ELEMENTS_MAINNET_CHAIN:-liquidv1}"
	else 
		CHAIN=""
	fi
	
	if [[ "$CHAIN" ]]; then
		CONFIG_PREFIX="chain=${CHAIN}${NL}[${CHAIN}]"
	fi
	
	if [[ "$ELEMENTS_WALLETDIR" ]] && [[ "$CHAIN" ]]; then
		
		WALLETDIR="$ELEMENTS_WALLETDIR/${CHAIN}"
		mkdir -p "$WALLETDIR"	
		chown -R elements:elements "$WALLETDIR"
		CONFIG_PREFIX="${CONFIG_PREFIX}${NL}walletdir=${WALLETDIR}${NL}"
	fi

	cat <<-EOF > "$ELEMENTS_DATA/elements.conf"
	${CONFIG_PREFIX}
	printtoconsole=1
	rpcallowip=::/0
	${ELEMENTS_EXTRA_ARGS}
	EOF
	chown elements:elements "$ELEMENTS_DATA/elements.conf"

	if [[ "${ELEMENTS_TORCONTROL}" ]]; then
		# Because elementsd only accept torcontrol= host as an ip only, we resolve it here and add to config
		TOR_CONTROL_HOST=$(echo ${ELEMENTS_TORCONTROL} | cut -d ':' -f 1)
		TOR_CONTROL_PORT=$(echo ${ELEMENTS_TORCONTROL} | cut -d ':' -f 2)
		if [[ "$TOR_CONTROL_HOST" ]] && [[ "$TOR_CONTROL_PORT" ]]; then
			TOR_IP=$(getent hosts $TOR_CONTROL_HOST | cut -d ' ' -f 1)
			echo "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" >> "$ELEMENTS_DATA/elements.conf"
			echo "Added "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" to $ELEMENTS_DATA/elements.conf"
		else
			echo "Invalid ELEMENTS_TORCONTROL"
		fi
	fi

	# ensure correct ownership and linking of data directory
	# we do not update group ownership here, in case users want to mount
	# a host directory and still retain access to it
	chown -R elements "$ELEMENTS_DATA"
	ln -sfn "$ELEMENTS_DATA" /home/elements/.elements
	chown -h elements:elements /home/elements/.elements

	exec gosu elements "$@"
else
	exec "$@"
fi
