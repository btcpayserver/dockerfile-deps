FROM debian:stretch-slim as builder

WORKDIR /LND-backup

COPY . /LND-backup

ENTRYPOINT ["lnd-channels-backup-dependencies.sh"]
