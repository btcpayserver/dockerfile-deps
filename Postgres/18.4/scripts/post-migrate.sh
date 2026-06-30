set -Eeo pipefail
shopt -s extglob


if [ "$(id -u)" = '0' ]; then
	echo "Error: You need to run post-migrate.sh as postgres user"
	exit 1
fi

source /usr/local/bin/docker-entrypoint.sh

echo "Running vacuum analyze..."
docker_temp_server_start "$@"

if [[ -f "/update_extensions.sql" ]]; then
	echo "Running extension update script: /update_extensions.sql"
	psql --file="/update_extensions.sql"
fi

vacuumdb --all --analyze-only --missing-stats-only

docker_temp_server_stop