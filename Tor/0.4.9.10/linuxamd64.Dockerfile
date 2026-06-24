# Thanks to https://hub.docker.com/r/chriswayg/tor-alpine/dockerfile (Christian chriswayg@gmail.com)
# Dockerfile for Tor Relay Server with obfs4proxy (Multi-Stage build)

FROM debian:bookworm-slim AS tor-build
ENV TOR_VERSION=0.4.9.10
ENV TOR_HASH=dfee904eae8fc38a2e3b351154f8ac0fca2a6649038f1a7e6a59461de57da47f

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates perl autoconf automake build-essential git libtool python3 wget gnupg dirmngr git pkg-config

ENV QEMU_LD_PREFIX=/usr/libs

RUN wget -q https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz \
&& TAR_NAME=zlib-1.3.2.tar.gz \
&& FOLDER_NAME=zlib-1.3.2 \
&& echo "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./configure \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/openssl/openssl/releases/download/openssl-3.5.6/openssl-3.5.6.tar.gz \
&& mkdir /usr/openssl \
&& TAR_NAME=openssl-3.5.6.tar.gz \
&& FOLDER_NAME=openssl-3.5.6 \
&& echo "deae7c80cba99c4b4f940ecadb3c3338b13cb77418409238e57d7f31f2a3b736 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./Configure no-dso no-zlib no-asm \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz \
&& TAR_NAME=libevent-2.1.12-stable.tar.gz \
&& FOLDER_NAME=libevent-2.1.12-stable \
&& echo "92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./autogen.sh \
&& ./configure --disable-shared --with-pic --disable-samples --disable-libevent-regress \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

# Install Tor from source, incl. GeoIP files (get latest release version number from Tor ReleaseNotes)
RUN TOR_TARBALL_NAME="tor-${TOR_VERSION}.tar.gz" \
      && TOR_TARBALL_LINK="https://dist.torproject.org/${TOR_TARBALL_NAME}" \
      && wget -q $TOR_TARBALL_LINK \
      && echo "${TOR_HASH}  ${TOR_TARBALL_NAME}" | sha256sum -c - \
      && tar xf $TOR_TARBALL_NAME \
      && cd tor-$TOR_VERSION \
      && ./configure \
      --disable-zstd --disable-lzma \
      --disable-systemd --disable-seccomp --disable-unittests --disable-tool-name-check \
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

FROM debian:bookworm-slim

ENV TOR_VERSION=0.4.9.10

# Copy Tor
COPY --from=tor-build "/tmp/bin" /usr/local/bin
COPY --from=tor-build /usr/local/ /usr/local/

ENV TOR_DATA /home/tor/.tor

RUN chmod +x /usr/local/bin/gosu && groupadd -r tor && useradd -r -m -g tor tor && mkdir -p ${TOR_DATA} && chown -R tor:tor "$TOR_DATA" \
  && cp -r /usr/local/lib64/* /usr/local/lib/ && ldconfig

VOLUME /home/tor/.tor
COPY docker-entrypoint.sh /entrypoint.sh

# SOCKS5, TOR control
EXPOSE 9050 9051
ENV TOR_CONFIG=/usr/local/etc/tor/torrc

ENTRYPOINT ["./entrypoint.sh"]
CMD ["tor"]
