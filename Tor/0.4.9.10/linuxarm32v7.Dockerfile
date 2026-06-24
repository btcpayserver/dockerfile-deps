FROM debian:bookworm-slim as download

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget \
     qemu-user-static binfmt-support

WORKDIR /tmp/bin
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.13/gosu-armhf" \
	  && echo "33e421b84b3f746e7353ac2e7c9f199c5beef5a3b2b7a013b591a9af25d84919 gosu" | sha256sum -c -

FROM debian:bookworm-slim as tor-build

ENV TOR_VERSION=0.4.9.10
ENV TOR_HASH=dfee904eae8fc38a2e3b351154f8ac0fca2a6649038f1a7e6a59461de57da47f

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates perl autoconf automake build-essential git libtool python3 wget gnupg dirmngr git pkg-config \
  libc6-armhf-cross gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

ENV target_host=arm-linux-gnueabihf

ENV AR=${target_host}-ar \
AS=${target_host}-as \
CC=${target_host}-gcc \
CXX=${target_host}-g++ \
LD=${target_host}-ld \
STRIP=${target_host}-strip \
QEMU_LD_PREFIX=/usr/${target_host} \
HOST=${target_host}

# See dependency versions on https://gitlab.torproject.org/tpo/applications/tor-browser-build/-/blob/main/projects

RUN wget -q https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz \
&& TAR_NAME=zlib-1.3.2.tar.gz \
&& FOLDER_NAME=zlib-1.3.2 \
&& echo "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./configure --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/openssl/openssl/releases/download/openssl-3.5.6/openssl-3.5.6.tar.gz \
&& TAR_NAME=openssl-3.5.6.tar.gz \
&& FOLDER_NAME=openssl-3.5.6 \
&& echo "deae7c80cba99c4b4f940ecadb3c3338b13cb77418409238e57d7f31f2a3b736 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./Configure --prefix=$QEMU_LD_PREFIX linux-armv4 -march=armv7+fp no-dso no-zlib no-asm \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz \
&& TAR_NAME=libevent-2.1.12-stable.tar.gz \
&& FOLDER_NAME=libevent-2.1.12-stable \
&& echo "92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./autogen.sh \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --with-pic --disable-samples --disable-libevent-regress \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

# https://trac.torproject.org/projects/tor/ticket/27802
RUN wget -q https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz \
&& TAR_NAME=tor-${TOR_VERSION}.tar.gz \
&& FOLDER_NAME=tor-${TOR_VERSION} \
&& echo "${TOR_HASH} $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-gcc-hardening --disable-asciidoc \
    --disable-zstd --disable-lzma \
    --with-libevent-dir="$QEMU_LD_PREFIX" \
    --with-openssl-dir="$QEMU_LD_PREFIX" \
    --with-zlib-dir="$QEMU_LD_PREFIX" \
    --disable-systemd --disable-seccomp --disable-unittests --disable-tool-name-check \
    --sysconfdir=/usr/local/etc \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME \
&& ${STRIP} /usr/arm-linux-gnueabihf/bin/tor-* && ${STRIP} /usr/arm-linux-gnueabihf/bin/tor

FROM --platform=linux/arm/v7 arm32v7/debian:bookworm-slim
ENV target_host=arm-linux-gnueabihf
ENV QEMU_LD_PREFIX=/usr/${target_host}

COPY --from=download /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
COPY --from=download "/tmp/bin" /usr/local/bin
COPY --from=tor-build ${QEMU_LD_PREFIX}/bin/tor* /usr/bin/
COPY --from=tor-build ${QEMU_LD_PREFIX} /usr/local/
COPY --from=tor-build ${QEMU_LD_PREFIX}/share/tor/ ${QEMU_LD_PREFIX}/share/tor/

ENV TOR_DATA /home/tor/.tor
RUN chmod +x /usr/local/bin/gosu && groupadd -r tor && useradd -r -m -g tor tor && \
    mkdir -p ${TOR_DATA} && chown -R tor:tor "$TOR_DATA" && \
    rm -rf /lib/arm-linux-gnueabihf/libz* && ldconfig

VOLUME /home/tor/.tor

COPY docker-entrypoint.sh /entrypoint.sh

# SOCKS5, TOR control
EXPOSE 9050 9051
ENV TOR_CONFIG=/usr/local/etc/tor/torrc

RUN  rm -rf /usr/arm-linux-gnueabihf/etc/tor \
   && mkdir -p /usr/arm-linux-gnueabihf/etc \
   && mkdir -p /usr/local/etc/tor \
   && ln -sfn /usr/local/etc/tor /usr/arm-linux-gnueabihf/etc/tor

ENTRYPOINT ["./entrypoint.sh"]
CMD ["tor"]
