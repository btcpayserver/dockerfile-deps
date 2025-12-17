FROM  postgres:18.1 as downloader

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

FROM --platform=arm postgres:18.1
COPY --from=downloader /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static

# Postgres doesn't ship packages for 13
ENV PREVIOUS_VERSION 13
RUN FALLBACK="http://aois.blob.core.windows.net/public/$PREVIOUS_VERSION-$(uname -m).tar.gz" && \
    FALLBACK_SHARE="http://aois.blob.core.windows.net/public/share-$PREVIOUS_VERSION-$(uname -m).tar.gz" && \
    apt-get update && apt-get install  --no-install-recommends -y wget && \
    rm -rf /var/lib/apt/lists/* && \
    cd /usr/lib/postgresql && \
    wget $FALLBACK && \
    echo "250773d9a043478530b8b1c705bffb29205b5eb9e6bdcfac1882f32efd5c6ab5 $PREVIOUS_VERSION-$(uname -m).tar.gz" | sha256sum -c - && \
    tar -xvf *.tar.gz && \
    rm -f *.tar.gz && \
    cd /usr/share/postgresql && \
    wget $FALLBACK_SHARE && \
    echo "7753d7dbc5856f45120a45ad05d25a27e5d3e4f5940ca9371b1f2c8fba701317 share-$PREVIOUS_VERSION-$(uname -m).tar.gz" | sha256sum -c - && \
    tar -xvf *.tar.gz && \
    rm -f *.tar.gz

COPY scripts /scripts
ENTRYPOINT ["/scripts/migrate-docker-entrypoint.sh"]
CMD ["postgres"]