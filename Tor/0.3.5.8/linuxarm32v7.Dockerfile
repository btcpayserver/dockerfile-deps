FROM debian:stretch-slim as download

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget \
     qemu qemu-user-static qemu-user binfmt-support

WORKDIR /tmp/bin
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-armhf" \
	  && echo "171b4a2decc920de0dd4f49278d3e14712da5fa48de57c556f99bcdabe03552e gosu" | sha256sum -c -

FROM debian:stretch-slim as tor-build

ARG TOR_GPG_KEY=0x6AFEE6D49E92B601
ENV TOR_VERSION=0.3.5.8

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates perl autoconf automake build-essential git libtool python python3 wget gnupg dirmngr git \
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

RUN wget -q https://zlib.net/zlib-1.2.11.tar.gz \
&& tar xvf zlib-1.2.11.tar.gz \
&& cd zlib-1.2.11 \
&& ./configure --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm zlib-1.2.11.tar.gz && rm -rf zlib-1.2.11

RUN wget -q https://github.com/openssl/openssl/archive/OpenSSL_1_0_2r.tar.gz \
&& tar xvf OpenSSL_1_0_2r.tar.gz \
&& cd openssl-OpenSSL_1_0_2r \
&& ./Configure --prefix=$QEMU_LD_PREFIX linux-armv4 -march=armv7 no-shared no-dso no-zlib no-asm \
&& make \
&& make install && cd .. && rm OpenSSL_1_0_2r.tar.gz && rm -rf openssl-OpenSSL_1_0_2r

RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz \
&& tar xvf libevent-2.1.8-stable.tar.gz \
&& cd libevent-2.1.8-stable \
&& ./autogen.sh \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-shared --enable-static --with-pic --disable-samples --disable-libevent-regress \
&& make \
&& make install && cd .. && rm libevent-2.1.8-stable.tar.gz && rm -rf libevent-2.1.8-stable

RUN wget -q https://www.torproject.org/dist/tor-0.3.5.8.tar.gz \
&& tar xvf tor-0.3.5.8.tar.gz \
&& cd tor-0.3.5.8 \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-gcc-hardening --disable-system-torrc --disable-asciidoc \
    --enable-static-tor \
    --enable-static-libevent --with-libevent-dir=$QEMU_LD_PREFIX \
    --enable-static-openssl --with-openssl-dir=$QEMU_LD_PREFIX \
    --enable-static-zlib --with-zlib-dir=$QEMU_LD_PREFIX \
    --disable-systemd --disable-lzma --disable-seccomp --disable-unittests --disable-zstd-advanced-apis \
&& make \
&& make install && cd .. && rm tor-0.3.5.8.tar.gz && rm -rf tor-0.3.5.8

FROM arm32v7/debian:stretch-slim

COPY --from=download /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
COPY --from=download "/tmp/bin" /usr/local/bin
COPY --from=tor-build /usr/arm-linux-gnueabihf/bin/tor* /usr/bin/
COPY --from=tor-build /usr/arm-linux-gnueabihf/share/tor/ /usr/bin/share/tor/

RUN chmod +x /usr/local/bin/gosu && groupadd -r tor && useradd -r -m -g tor tor

# Persist data
VOLUME /etc/tor /var/lib/tor
COPY docker-entrypoint.sh /entrypoint.sh

# SOCKS5, TOR control
EXPOSE 9050 9051

ENTRYPOINT ["./entrypoint.sh"]
CMD ["tor"]