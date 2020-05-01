# Thanks to https://hub.docker.com/r/chriswayg/tor-alpine/dockerfile (Christian chriswayg@gmail.com)
# Dockerfile for Tor Relay Server with obfs4proxy (Multi-Stage build)

FROM alpine:3.7 AS tor-build
ARG TOR_GPG_KEY=0x6AFEE6D49E92B601
ENV TOR_VERSION=0.4.2.7
# Install prerequisites
RUN apk --no-cache add --update \
        gnupg \
        build-base \
        libevent \
        libevent-dev \
        libressl \
        libressl-dev \
        xz-libs \
        xz-dev \
        zlib \
        zlib-dev \
        zstd \
        zstd-dev \
      # Install Tor from source, incl. GeoIP files (get latest release version number from Tor ReleaseNotes)
      && TOR_TARBALL_NAME="tor-${TOR_VERSION}.tar.gz" \
      && TOR_TARBALL_LINK="https://dist.torproject.org/${TOR_TARBALL_NAME}" \
      && wget -q $TOR_TARBALL_LINK \
      && wget $TOR_TARBALL_LINK.asc \
    # Reliably fetch the TOR_GPG_KEY
        && found=''; \
         	for server in \
           		ha.pool.sks-keyservers.net \
           		hkp://keyserver.ubuntu.com:80 \
           		hkp://p80.pool.sks-keyservers.net:80 \
               ipv4.pool.sks-keyservers.net \
               keys.gnupg.net \
           		pgp.mit.edu \
         	; do \
         		echo "Fetching GPG key $TOR_GPG_KEY from $server"; \
         		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$TOR_GPG_KEY" && found=yes && break; \
         	done; \
         	test -z "$found" && echo >&2 "error: failed to fetch GPG key $TOR_GPG_KEY" && exit 1; \
        gpg --verify $TOR_TARBALL_NAME.asc \
      && tar xf $TOR_TARBALL_NAME \
      && cd tor-$TOR_VERSION \
      && ./configure --disable-unittests --disable-systemd --disable-seccomp --disable-asciidoc \
      && make install \
      && ls -R /usr/local/ \
      && strip /usr/local/bin/tor-* && strip /usr/local/bin/tor
      # Main files created (plus docs):
        # /usr/local/bin/tor
        # /usr/local/bin/tor-gencert
        # /usr/local/bin/tor-resolve
        # /usr/local/bin/torify
        # /usr/local/share/tor/geoip
        # /usr/local/share/tor/geoip6
        # /usr/local/etc/tor/torrc.sample

WORKDIR /tmp/bin
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" \
	&& echo "0b843df6d86e270c5b0f5cbd3c326a04e18f4b7f9b8457fa497b0454c4b138d7  gosu" | sha256sum -c -

FROM alpine:3.7


# Installing dependencies of Tor
RUN apk --no-cache add --update \
      libevent \
      libressl \
      xz-libs \
      zlib \
      zstd

# Copy Tor
COPY --from=tor-build "/tmp/bin" /usr/local/bin
COPY --from=tor-build /usr/local/ /usr/local/

ENV TOR_DATA /home/tor/.tor
RUN chmod +x /usr/local/bin/gosu && addgroup -g 19001 -S tor && adduser -u 19001 -G tor -S tor && mkdir -p ${TOR_DATA} && chown -R tor:tor "$TOR_DATA"

VOLUME /home/tor/.tor
COPY docker-entrypoint.sh /entrypoint.sh

# SOCKS5, TOR control
EXPOSE 9050 9051
ENV TOR_CONFIG=/usr/local/etc/tor/torrc

ENTRYPOINT ["./entrypoint.sh"]
CMD ["tor"]