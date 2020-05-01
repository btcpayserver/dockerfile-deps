FROM debian:stretch-slim as download

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget \
     qemu qemu-user-static qemu-user binfmt-support

WORKDIR /tmp/bin
RUN wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-arm64" \
	  && echo "5e279972a1c7adee65e3b5661788e8706594b458b7ce318fecbd392492cc4dbd gosu" | sha256sum -c -

FROM debian:stretch-slim as tor-build

ARG TOR_GPG_KEY=0x6AFEE6D49E92B601
ENV TOR_VERSION=0.4.2.7
ENV TOR_HASH=06a1d835ddf382f6bca40a62e8fb40b71b2f73d56f0d53523c8bd5caf9b3026d

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates perl autoconf automake build-essential git libtool python python3 wget gnupg dirmngr git \
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

RUN wget -q https://zlib.net/zlib-1.2.11.tar.gz \
&& TAR_NAME=zlib-1.2.11.tar.gz \
&& FOLDER_NAME=zlib-1.2.11 \
&& echo "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./configure --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/openssl/openssl/archive/OpenSSL_1_0_2s.tar.gz \
&& TAR_NAME=OpenSSL_1_0_2s.tar.gz \
&& FOLDER_NAME=openssl-OpenSSL_1_0_2s \
&& echo "f84db9e154d1a8f3013be98b574dc8fca23089fffffae2abaf8683e0b9a41c42 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./Configure --prefix=$QEMU_LD_PREFIX linux-aarch64 no-shared no-dso no-zlib no-asm \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz \
&& TAR_NAME=libevent-2.1.8-stable.tar.gz \
&& FOLDER_NAME=libevent-2.1.8-stable \
&& echo "965cc5a8bb46ce4199a47e9b2c9e1cae3b137e8356ffdad6d94d3b9069b71dc2 $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./autogen.sh \
&& ./configure --prefix=$QEMU_LD_PREFIX --host=${target_host} --disable-shared --enable-static --with-pic --disable-samples --disable-libevent-regress \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

# For lzma and zstd, we do not override prefix because those are discovered thanks to pkg-config during Tor build
# I did not managed to make pkg-config discover pkg on a different prefix...
RUN apt-get install -y autopoint && wget -q https://jaist.dl.sourceforge.net/project/lzmautils/xz-5.2.3.tar.gz \
&& TAR_NAME=xz-5.2.3.tar.gz \
&& FOLDER_NAME=xz-5.2.3 \
&& echo "71928b357d0a09a12a4b4c5fafca8c31c19b0e7d3b8ebb19622e96f26dbf28cb $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& ./autogen.sh \
&& ./configure --host=${target_host} --disable-shared --enable-static --disable-doc --disable-scripts --disable-xz --disable-xzdec --disable-lzmadec \
                                        --disable-lzmainfo --disable-lzma-links \
&& make \
&& make install \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

RUN wget -q https://github.com/facebook/zstd/archive/v1.3.2.tar.gz \
&& TAR_NAME=v1.3.2.tar.gz \
&& FOLDER_NAME=zstd-1.3.2 \
&& echo "ac5054a3c64e6510bc1ae890d05e3d271cc33ceebc9d06ac9f08105766d2798a $TAR_NAME" | sha256sum -c - \
&& tar xvf $TAR_NAME \
&& cd $FOLDER_NAME \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME

# https://trac.torproject.org/projects/tor/ticket/27802
RUN apt-get install -y pkg-config && wget -q https://www.torproject.org/dist/tor-${TOR_VERSION}.tar.gz \
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
    --enable-zstd --enable-lzma \
    --disable-systemd --disable-seccomp --disable-unittests --disable-tool-name-check \
&& make \
&& make install && cd .. && rm $TAR_NAME && rm -rf $FOLDER_NAME \
&& ${STRIP} /usr/aarch64-linux-gnu/bin/tor-* && ${STRIP} /usr/aarch64-linux-gnu/bin/tor

FROM arm64v8/debian:stretch-slim
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