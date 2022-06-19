FROM  postgres:13.7 as downloader

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

FROM --platform=arm  postgres:13.7
COPY --from=downloader /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static

# Postgres doesn't ship packages for 9.6
ENV PREVIOUS_VERSION 9.6
RUN FALLBACK="http://aois.blob.core.windows.net/public/$PREVIOUS_VERSION-$(uname -m).tar.gz" && \
    FALLBACK_SHARE="http://aois.blob.core.windows.net/public/share-$PREVIOUS_VERSION-$(uname -m).tar.gz" && \
    apt-get update && apt-get install  --no-install-recommends -y wget && \
    rm -rf /var/lib/apt/lists/* && \
    cd /usr/lib/postgresql && \
    wget $FALLBACK && \
    echo "50a98f90ad9c61d0b5b5ccb9c984ca48bd6e6f331ed17eb87086a2c4290c75c6 9.6-armv7l.tar.gz" | sha256sum -c - && \
    tar -xvf *.tar.gz && \
    rm -f *.tar.gz && \
    cd /usr/share/postgresql && \
    wget $FALLBACK_SHARE && \
    echo "10c8c66d97fcb1cd9b22334118ba5afd495147c94f3a03409ca98da54643b433 share-9.6-armv7l.tar.gz" | sha256sum -c - && \
    tar -xvf *.tar.gz && \
    rm -f *.tar.gz

COPY migrate-docker-entrypoint.sh /migrate-docker-entrypoint.sh

ENTRYPOINT ["/migrate-docker-entrypoint.sh"]
CMD ["postgres"]