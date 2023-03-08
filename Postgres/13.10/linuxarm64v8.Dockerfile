FROM  postgres:13.10 as downloader

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

FROM --platform=arm64 postgres:13.10
COPY --from=downloader /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV PREVIOUS_VERSION 9.6
RUN cp /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list.backup && \
    sed -i "s/$/ $PREVIOUS_VERSION/" /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-$PREVIOUS_VERSION \
    postgresql-contrib-$PREVIOUS_VERSION && \
    rm /etc/apt/sources.list.d/pgdg.list && mv /etc/apt/sources.list.d/pgdg.list.backup /etc/apt/sources.list.d/pgdg.list && \
    rm -rf /var/lib/apt/lists/*

COPY migrate-docker-entrypoint.sh /migrate-docker-entrypoint.sh

ENTRYPOINT ["/migrate-docker-entrypoint.sh"]
CMD ["postgres"]