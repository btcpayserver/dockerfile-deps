FROM debian:bookworm-slim as download

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget \
     qemu-user-static binfmt-support

WORKDIR /tmp/bin
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.13/gosu-arm64" \
	  && echo "578b2c70936cae372f6826585f82e76de5858342dd179605a8cb58d58828a079 gosu" | sha256sum -c -

FROM debian:bookworm-slim as tor-build

ENV TOR_VERSION=0.4.8.10
ENV TOR_HASH=e628b4fab70edb4727715b23cf2931375a9f7685ac08f2c59ea498a178463a86

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates perl autoconf automake build-essential git libtool python3 wget gnupg dirmngr git pkg-config \
  libc6-arm64-cross gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

ENV target_host=aarch64-linux-gnu

ENV AR=${target_host}-ar \
AS=${target_host}-as \
CC=${target_host}-gcc \
CXX=${target_host}-g++ \
LD=${target_host}-ld \
STRIP=${target_host}-strip \
QEMU_LD_PREFIX=/usr/${target_host} \
HOST=${target_host}

# See dependency versions on https://gitlab.torproject.org/tpo/applications/tor-browser-build/-/blob/main/projects
RUN wget -q https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz \
&& TAR_NAME=zlib-1.3.tar.gz \
&& FOLDER_NAME=zlib-1.3 \
&& echo "ff0ba4c292013dbc27530b3a81e1f9a813cd39de01ca5e0f8bf355702efa593e $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./configure --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/openssl/openssl/releases/download/openssl-3.0.12/openssl-3.0.12.tar.gz \
&& TAR_NAME=openssl-3.0.12.tar.gz \
&& FOLDER_NAME=openssl-3.0.12 \
&& echo "f93c9e8edde5e9166119de31755fc87b4aa34863662f67ddfcba14d0b6b69b61 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./Configure --prefix=$QEMU_LD_PREFIX linux-aarch64 no-shared no-dso no-zlib no-asm \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz \
&& TAR_NAME=libevent-2.1.12-stable.tar.gz \
&& FOLDER_NAME=libevent-2.1.12-stable \
&& echo "92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./autogen.sh \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-shared --enable-static --with-pic --disable-samples --disable-libevent-regress \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

# https://trac.torproject.org/projects/tor/ticket/27802
RUN wget -q https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz \
&& TAR_NAME=tor-${TOR_VERSION}.tar.gz \
&& FOLDER_NAME=tor-${TOR_VERSION} \
&& echo "${TOR_HASH} $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& LIBS="-lssl -lcrypto -lpthread -ldl" ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-gcc-hardening --disable-asciidoc \
    --enable-static-tor \
    --enable-static-libevent --with-libevent-dir=$QEMU_LD_PREFIX \
    --enable-static-openssl --with-openssl-dir=$QEMU_LD_PREFIX \
    --enable-static-zlib --with-zlib-dir=$QEMU_LD_PREFIX \
    --disable-zstd --disable-lzma \
    --disable-systemd --disable-seccomp --disable-unittests --disable-tool-name-check \
    --sysconfdir=/usr/local/etc \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME \
&& ${STRIP} /usr/aarch64-linux-gnu/bin/tor-* && ${STRIP} /usr/aarch64-linux-gnu/bin/tor

FROM arm64v8/debian:bookworm-slim
ENV target_host=aarch64-linux-gnu
ENV QEMU_LD_PREFIX=/usr/${target_host}
COPY --from=download /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static
COPY --from=download "/tmp/bin" /usr/local/bin
COPY --from=tor-build /usr/aarch64-linux-gnu/bin/tor* /usr/bin/
COPY --from=tor-build ${QEMU_LD_PREFIX}/share/tor/ ${QEMU_LD_PREFIX}/share/tor/

ENV TOR_DATA /home/tor/.tor
RUN chmod +x /usr/local/bin/gosu && groupadd -r tor && useradd -r -m -g tor tor && mkdir -p ${TOR_DATA} && chown -R tor:tor "$TOR_DATA"

VOLUME /home/tor/.tor

COPY docker-entrypoint.sh /entrypoint.sh

# SOCKS5, TOR control
EXPOSE 9050 9051
ENV TOR_CONFIG=/usr/local/etc/tor/torrc

RUN rm -rf /usr/aarch64-linux-gnu/etc/tor \
   && mkdir -p /usr/aarch64-linux-gnu/etc \
   && mkdir -p /usr/local/etc/tor \
   && ln -sfn /usr/local/etc/tor /usr/aarch64-linux-gnu/etc/tor

ENTRYPOINT ["./entrypoint.sh"]
CMD ["tor"]