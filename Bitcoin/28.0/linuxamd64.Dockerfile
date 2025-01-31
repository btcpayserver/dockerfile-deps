FROM debian:bookworm-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV BITCOIN_VERSION 28.0
ENV BITCOIN_URL https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV BITCOIN_SHA256 7fe294b02b25b51acb8e8e0a0eb5af6bbafa7cd0c5b0e5fcbb61263104a82fbc

# install bitcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO bitcoin.tar.gz "$BITCOIN_URL" \
	&& echo "$BITCOIN_SHA256 bitcoin.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf bitcoin.tar.gz -C /tmp/bin --strip-components=2 "bitcoin-$BITCOIN_VERSION/bin/bitcoin-cli" "bitcoin-$BITCOIN_VERSION/bin/bitcoind" "bitcoin-$BITCOIN_VERSION/bin/bitcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" \
	&& echo "bbc4136d03ab138b1ad66fa4fc051bafc6cc7ffae632b069a53657279a450de3 gosu" | sha256sum -c -

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
