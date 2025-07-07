# Use manifest image which support all architecture
FROM debian:bookworm-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget
RUN apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

ENV GROESTLCOIN_VERSION 28.0
ENV GROESTLCOIN_TARBALL groestlcoin-${GROESTLCOIN_VERSION}-aarch64-linux-gnu.tar.gz
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v$GROESTLCOIN_VERSION/$GROESTLCOIN_TARBALL
ENV GROESTLCOIN_SHA256 092c6ff333a3defe2603b91c55aea6415e554a2bbc6abb3ad43ac712fa9b63b1

# install groestlcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO $GROESTLCOIN_TARBALL "$GROESTLCOIN_URL" \
	&& echo "$GROESTLCOIN_SHA256 $GROESTLCOIN_TARBALL" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf $GROESTLCOIN_TARBALL -C /tmp/bin --strip-components=2 "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-cli" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoind" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.16/gosu-arm64" \
	&& echo "23fa49907d5246d2e257de3bf883f57fba47fe1f559f7e732ff16c0f23d2b6a6 gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM --platform=arm64 debian:bookworm-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ARG GROESTLCOIN_USER_ID=999
ARG GROESTLCOIN_GROUP_ID=999

RUN apt-get update && \
    apt-get install -qq --no-install-recommends xxd && \
    rm -rf /var/lib/apt/lists/*
RUN chmod +x /usr/local/bin/gosu && groupadd -r -g $GROESTLCOIN_GROUP_ID groestlcoin && useradd -r -m -u $GROESTLCOIN_USER_ID -g groestlcoin groestlcoin

# create data directory
ENV GROESTLCOIN_DATA /data
RUN mkdir "$GROESTLCOIN_DATA" \
	&& chown -R groestlcoin:groestlcoin "$GROESTLCOIN_DATA" \
	&& ln -sfn "$GROESTLCOIN_DATA" /home/groestlcoin/.groestlcoin \
	&& chown -h groestlcoin:groestlcoin /home/groestlcoin/.groestlcoin

VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1331 1441 17777 17766 18888 18443 31331 31441
CMD ["groestlcoind"]
