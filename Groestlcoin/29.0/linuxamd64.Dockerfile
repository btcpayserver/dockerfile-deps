FROM debian:bookworm-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV GROESTLCOIN_VERSION 29.0
ENV GROESTLCOIN_TARBALL groestlcoin-${GROESTLCOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v$GROESTLCOIN_VERSION/$GROESTLCOIN_TARBALL
ENV GROESTLCOIN_SHA256 e0b3e3d96caf908060779c0d9964c777ccc4b7364af54404ff1768e018e56768

# install groestlcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO $GROESTLCOIN_TARBALL "$GROESTLCOIN_URL" \
	&& echo "$GROESTLCOIN_SHA256 $GROESTLCOIN_TARBALL" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf $GROESTLCOIN_TARBALL -C /tmp/bin --strip-components=2 "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-cli" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoind" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.16/gosu-amd64" \
	&& echo "3a4e1fc7430f9e7dd7b0cbbe0bfde26bf4a250702e84cf48a1eb2b631c64cf13 gosu" | sha256sum -c -

FROM debian:bookworm-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

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
