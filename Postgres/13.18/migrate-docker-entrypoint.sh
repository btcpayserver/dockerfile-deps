#!/usr/bin/env bash
set -Eeo pipefail
shopt -s extglob

CURRENT_PGVERSION=""
EXPECTED_PGVERSION="$PG_MAJOR"
if [[ -f "/var/lib/postgresql/data/PG_VERSION" ]]; then
    CURRENT_PGVERSION="$(cat /var/lib/postgresql/data/PG_VERSION)"
elif [[ -f "/var/lib/postgresql/data/PG_MIGRATING_FROM_VERSION" ]]; then
    echo "Previous migration failed"
    CURRENT_PGVERSION="$(cat /var/lib/postgresql/data/PG_MIGRATING_FROM_VERSION)"
fi

if [[ "$CURRENT_PGVERSION" != "$EXPECTED_PGVERSION" ]] && \
   [[ "$CURRENT_PGVERSION" != "" ]]; then

    if ! [ -f "/usr/lib/postgresql/$CURRENT_PGVERSION/bin/pg_upgrade" ]; then
        echo "Trying to install Postgres $CURRENT_PGVERSION migration tools"
        sed -i "s/$/ $CURRENT_PGVERSION/" /etc/apt/sources.list.d/pgdg.list
        if ! apt-get update; then
            echo "apt-get update failed. Are you using raspberry pi 4? If yes, please follow https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/"
            exit 1
        fi
        if ! apt-get install -y --no-install-recommends \
                postgresql-$CURRENT_PGVERSION \
                postgresql-contrib-$CURRENT_PGVERSION; then
                # On arm32, postgres doesn't ship those packages, so we download
                # the binaries from an archive we built from the postgres 9.6.20 image's binaries
                FALLBACK="https://aois.blob.core.windows.net/public/$CURRENT_PGVERSION-$(uname -m).tar.gz"
                FALLBACK_SHARE="https://aois.blob.core.windows.net/public/share-$CURRENT_PGVERSION-$(uname -m).tar.gz"
                echo "Failure to install postgresql-$CURRENT_PGVERSION and postgresql-contrib-$CURRENT_PGVERSION trying fallback $FALLBACK"
                apt-get install -y wget
                pushd . > /dev/null
                cd /usr/lib/postgresql
                wget $FALLBACK
                tar -xvf *.tar.gz
                rm -f *.tar.gz
                cd /usr/share/postgresql
                wget $FALLBACK_SHARE
                tar -xvf *.tar.gz
                rm -f *.tar.gz
                popd > /dev/null
                echo "Successfully installed PG utilities via the fallback"
        fi
    else
        echo "Migration binaries already present on the image"
    fi

    export PGBINOLD="/usr/lib/postgresql/$CURRENT_PGVERSION/bin"
    export PGDATABASE="/var/lib/postgresql/data"
    export PGDATAOLD="/var/lib/postgresql/data/$CURRENT_PGVERSION"
    export PGDATANEW="/var/lib/postgresql/data/$EXPECTED_PGVERSION"

    if ! [ -f "$PGDATABASE/PG_MIGRATING_FROM_VERSION" ]; then
        mkdir -p "$PGDATANEW" "$PGDATAOLD"
        find "$PGDATABASE" -maxdepth 1 -mindepth 1 \
                        -not -wholename "$PGDATAOLD" \
                        -not -wholename "$PGDATANEW" \
                        -exec mv {} "$PGDATAOLD/" \;
        cp "$PGDATAOLD/PG_VERSION" "$PGDATABASE/PG_MIGRATING_FROM_VERSION"
    else
        echo "Previous migration failed, trying one more time..."
    fi

    chmod 700 "$PGDATAOLD" "$PGDATANEW"
    chown postgres .
    chown -R postgres "$PGDATAOLD" "$PGDATANEW" "$PGDATABASE"

    [[ "$POSTGRES_USER" ]] && export PGUSER="$POSTGRES_USER"
    [[ "$POSTGRES_PASSWORD" ]] && export PGPASSWORD="$POSTGRES_PASSWORD"
    if [ ! -s "$PGDATANEW/PG_VERSION" ]; then
        if [[ "$PGUSER" ]]; then
            PGDATA="$PGDATANEW" eval "gosu postgres initdb -U$PGUSER $POSTGRES_INITDB_ARGS"
        else
            PGDATA="$PGDATANEW" eval "gosu postgres initdb $POSTGRES_INITDB_ARGS"
        fi
	fi

    if ! gosu postgres pg_upgrade; then
        echo "Failed to upgrade the server, showing pg_upgrade_server.log"
        cat pg_upgrade_server.log
        cp *.log "$PGDATABASE/"
        if [ -f "$PGDATAOLD/PG_VERSION" ] && [ -f "$PGDATANEW/PG_VERSION" ]; then
            echo "Cleaning up the new cluster"
            rm -r $PGDATANEW/*
        fi

        # If the db hasn't started cleanly, this may solve it.
        echo "Attempt to start/stop the old cluster if it hasn't exit cleanly"
        gosu postgres $PGBINOLD/pg_ctl start -w -D $PGDATAOLD
        gosu postgres $PGBINOLD/pg_ctl stop -w -D $PGDATAOLD

        exit 1
    fi

    rm "$PGDATABASE/PG_MIGRATING_FROM_VERSION"
    rm $PGDATANEW/*.conf
    mv $PGDATANEW/* "$PGDATABASE"
    mv $PGDATAOLD/*.conf "$PGDATABASE"
    rm -r "$PGDATANEW"
    ./delete_old_cluster.sh
    rm ./analyze_new_cluster.sh
    unset PGUSER
    unset PGPASSWORD
    unset PGDATABASE
fi

if [ -f "docker-entrypoint.sh" ]; then
    exec ./docker-entrypoint.sh  "$@"
else
    exec docker-entrypoint.sh  "$@"
fi