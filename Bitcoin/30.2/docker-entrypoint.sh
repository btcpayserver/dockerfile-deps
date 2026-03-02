#!/bin/bash
set -e

is_sqlite()
{
	local f=$1
	# read first 16 bytes and compare to the SQLite header
	printf 'SQLite format 3\0' | cmp -n 16 -s - "$f"
}

if [[ "$1" == "bitcoin-cli" || "$1" == "bitcoin-tx" || "$1" == "bitcoind" || "$1" == "test_bitcoin" ]]; then
	mkdir -p "$BITCOIN_DATA"

	CONFIG_PREFIX=""
	if [[ "${BITCOIN_NETWORK}" == "regtest" ]]; then
		CONFIG_PREFIX=$'regtest=1\n[regtest]'
	elif [[ "${BITCOIN_NETWORK}" == "testnet" ]]; then
		CONFIG_PREFIX=$'testnet=1\n[test]'
	elif [[ "${BITCOIN_NETWORK}" == "mainnet" ]]; then
		CONFIG_PREFIX=$'[main]'
	elif [[ "${BITCOIN_NETWORK}" == "signet" ]]; then
		CONFIG_PREFIX=$'signet=1\n[signet]'
	else 
		BITCOIN_NETWORK="mainnet"
		CONFIG_PREFIX=$'[main]'
	fi

	need_migrate=false
	if [[ "$BITCOIN_WALLETDIR" ]] && [[ "$BITCOIN_NETWORK" ]]; then
		NL=$'\n'
		WALLETDIR="$BITCOIN_WALLETDIR/${BITCOIN_NETWORK}"
		WALLETFILE="${WALLETDIR}/wallet.dat"
		mkdir -p "$WALLETDIR"
		chown -R bitcoin:bitcoin "$WALLETDIR"
		CONFIG_PREFIX="${CONFIG_PREFIX}${NL}walletdir=${WALLETDIR}${NL}"
		: "${CREATE_WALLET:=true}"
		if [[ "${CREATE_WALLET}" != "false" ]]; then
			if ! [[ -f "${WALLETFILE}" ]]; then
				echo "The wallet does not exists, creating it at ${WALLETDIR}..."
				gosu bitcoin bitcoin-wallet "-${BITCOIN_NETWORK}" "-datadir=${WALLETDIR}" "-wallet=" create
			elif ! is_sqlite "${WALLETFILE}"; then
				need_migrate=true
				echo "Legacy wallet migration needed"
			fi
		fi
	fi

	cat <<-EOF > "$BITCOIN_DATA/bitcoin.conf"
	${CONFIG_PREFIX}
	printtoconsole=1
	rpcallowip=::/0
	${BITCOIN_EXTRA_ARGS}
	EOF
	chown bitcoin:bitcoin "$BITCOIN_DATA/bitcoin.conf"

	if [[ "${BITCOIN_TORCONTROL}" ]]; then
		# Because bitcoind only accept torcontrol= host as an ip only, we resolve it here and add to config
		TOR_CONTROL_HOST=$(echo ${BITCOIN_TORCONTROL} | cut -d ':' -f 1)
		TOR_CONTROL_PORT=$(echo ${BITCOIN_TORCONTROL} | cut -d ':' -f 2)
		if [[ "$TOR_CONTROL_HOST" ]] && [[ "$TOR_CONTROL_PORT" ]]; then
			TOR_IP=$(getent hosts $TOR_CONTROL_HOST | cut -d ' ' -f 1)
			echo "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" >> "$BITCOIN_DATA/bitcoin.conf"
			echo "Added "torcontrol=$TOR_IP:$TOR_CONTROL_PORT" to $BITCOIN_DATA/bitcoin.conf"
		else
			echo "Invalid BITCOIN_TORCONTROL"
		fi
	fi

	# ensure correct ownership and linking of data directory
	# we do not update group ownership here, in case users want to mount
	# a host directory and still retain access to it
	chown -R bitcoin "$BITCOIN_DATA"
	ln -sfn "$BITCOIN_DATA" /home/bitcoin/.bitcoin
	chown -h bitcoin:bitcoin /home/bitcoin/.bitcoin
	rm -f /home/bitcoin/.bitcoin/settings.json

	if [[ "${need_migrate}" == "true" ]]; then
		echo "Migrating legacy bitcoin wallet..."
		gosu bitcoin "$@" &
		BITCOIN_PID=$!
		gosu bitcoin bitcoin-cli -datadir="${BITCOIN_DATA}" -rpcwait migratewallet ""
		gosu bitcoin bitcoin-cli -datadir="${BITCOIN_DATA}" -rpcwait stop
		wait "${BITCOIN_PID}"
		echo "Bitcoin legacy wallet migrated."
	fi

	exec gosu bitcoin "$@"
else
	exec "$@"
fi
