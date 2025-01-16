FROM debian:bookworm-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV BITCOIN_VERSION 28.1
ENV BITCOIN_URL https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV BITCOIN_SHA256 07f77afd326639145b9ba9562912b2ad2ccec47b8a305bd075b4f4cb127b7ed7

# install bitcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO bitcoin.tar.gz "$BITCOIN_URL" \
	&& echo "$BITCOIN_SHA256 bitcoin.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf bitcoin.tar.gz -C /tmp/bin --strip-components=2 "bitcoin-$BITCOIN_VERSION/bin/bitcoin-cli" "bitcoin-$BITCOIN_VERSION/bin/bitcoind" "bitcoin-$BITCOIN_VERSION/bin/bitcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.16/gosu-amd64" \
	&& echo "3a4e1fc7430f9e7dd7b0cbbe0bfde26bf4a250702e84cf48a1eb2b631c64cf13 gosu" | sha256sum -c -

FROM debian:bookworm-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

ARG BITCOIN_USER_ID=999
ARG BITCOIN_GROUP_ID=999

RUN apt-get update && \
    apt-get install -qq --no-install-recommends xxd && \
    rm -rf /var/lib/apt/lists/*
RUN chmod +x /usr/local/bin/gosu && groupadd -r -g $BITCOIN_GROUP_ID bitcoin && useradd -r -m -u $BITCOIN_USER_ID -g bitcoin bitcoin

# create data directory
ENV BITCOIN_DATA /data
RUN mkdir "$BITCOIN_DATA" \
	&& chown -R bitcoin:bitcoin "$BITCOIN_DATA" \
	&& ln -sfn "$BITCOIN_DATA" /home/bitcoin/.bitcoin \
	&& chown -h bitcoin:bitcoin /home/bitcoin/.bitcoin

VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8332 8333 18332 18333 18443 18444
CMD ["bitcoind"]
