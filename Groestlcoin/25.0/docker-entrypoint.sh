#!/bin/bash
set -e

if [[ "$1" == "groestlcoin-cli" || "$1" == "groestlcoin-tx" || "$1" == "groestlcoind" || "$1" == "test_groestlcoin" ]]; then
	mkdir -p "$GROESTLCOIN_DATA"

	CONFIG_PREFIX=""
	if [[ "${GROESTLCOIN_NETWORK}" == "regtest" ]]; then
		CONFIG_PREFIX=$'regtest=1\n[regtest]'
	elif [[ "${GROESTLCOIN_NETWORK}" == "testnet" ]]; then
		CONFIG_PREFIX=$'testnet=1\n[test]'
	elif [[ "${GROESTLCOIN_NETWORK}" == "mainnet" ]]; then
		CONFIG_PREFIX=$'mainnet=1\n[main]'
	elif [[ "${GROESTLCOIN_NETWORK}" == "signet" ]]; then
		CONFIG_PREFIX=$'signet=1\n[signet]'
	else
		GROESTLCOIN_NETWORK="mainnet"
		CONFIG_PREFIX=$'mainnet=1\n[main]'
	fi

	if [[ "$GROESTLCOIN_WALLETDIR" ]] && [[ "$GROESTLCOIN_NETWORK" ]]; then
		NL=$'\n'
		WALLETDIR="$GROESTLCOIN_WALLETDIR/${GROESTLCOIN_NETWORK}"
		WALLETFILE="${WALLETDIR}/wallet.dat"
		mkdir -p "$WALLETDIR"
		chown -R groestlcoin:groestlcoin "$WALLETDIR"
		CONFIG_PREFIX="${CONFIG_PREFIX}${NL}walletdir=${WALLETDIR}${NL}"
		: "${CREATE_WALLET:=true}"
		if ! [[ -f "${WALLETFILE}" ]] && [[ "${CREATE_WALLET}" != "false" ]]; then
		  echo "The wallet does not exists, creating it at ${WALLETDIR}..."
		  gosu groestlcoin groestlcoin-wallet "-datadir=${WALLETDIR}" "-legacy" "-wallet=" create
		fi
	fi

	cat <<-EOF > "$GROESTLCOIN_DATA/groestlcoin.conf"
	${CONFIG_PREFIX}
	printtoconsole=1
	rpcallowip=::/0
	${GROESTLCOIN_EXTRA_ARGS}
	EOF
	chown groestlcoin:groestlcoin "$GROESTLCOIN_DATA/groestlcoin.conf"

	if [[ "${GROESTLCOIN_TORCONTROL}" ]]; then
		# Because groestlcoind only accept torcontrol= host as an ip only, we resolve it here and add to config
		TOR_CONTROL_HOST=$(echo ${GROESTLCOIN_TORCONTROL} | cut -d ':' -f 1)
		TOR_CONTROL_PORT=$(echo ${GROESTLCOIN_TORCONTROL} | cut -d ':' -f 2)
		if [[ "$TOR_CONTROL_HOST" ]] && [[ "$TOR_CONTROL_PORT" ]]; then
			TOR_IP=$(getent hosts $TOR_CONTROL_HOST | cut -d ' ' -f 1)
			echo "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" >> "$GROESTLCOIN_DATA/groestlcoin.conf"
			echo "Added "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" to $GROESTLCOIN_DATA/groestlcoin.conf"
		else
			echo "Invalid GROESTLCOIN_TORCONTROL"
		fi
	fi

	# ensure correct ownership and linking of data directory
	# we do not update group ownership here, in case users want to mount
	# a host directory and still retain access to it
	chown -R groestlcoin "$GROESTLCOIN_DATA"
	ln -sfn "$GROESTLCOIN_DATA" /home/groestlcoin/.groestlcoin
	chown -h groestlcoin:groestlcoin /home/groestlcoin/.groestlcoin
	rm -f /home/groestlcoin/.groestlcoin/settings.json

	exec gosu groestlcoin "$@"
else
	exec "$@"
fi
