# Thanks to https://hub.docker.com/r/chriswayg/tor-alpine/dockerfile (Christian chriswayg@gmail.com)
# Dockerfile for Tor Relay Server with obfs4proxy (Multi-Stage build)

FROM alpine:3.18 AS tor-build
ENV TOR_VERSION=0.4.8.7
ENV TOR_HASH=b20d2b9c74db28a00c07f090ee5b0241b2b684f3afdecccc6b8008931c557491
# Install prerequisites
RUN apk --no-cache add --update \
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
      && echo "${TOR_HASH}  ${TOR_TARBALL_NAME}" | sha256sum -c - \
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
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.13/gosu-amd64" \
	&& echo "6f333f520d31e212634c0777213a5d4f8f26bba1ab4b0edbbdf3c8bff8896ecf  gosu" | sha256sum -c -

FROM alpine:3.18

ENV TOR_VERSION=0.4.7.8

# Installing dependencies of Tor
RUN apk --no-cache add --update \
      libevent \
      libressl \
      xz-libs \
      zlib \
      zstd \
      zstd-dev

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