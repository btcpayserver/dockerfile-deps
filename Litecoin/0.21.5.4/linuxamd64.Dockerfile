FROM debian:bookworm-slim as builder

RUN groupadd -r bitcoin && useradd -r -m -g bitcoin bitcoin

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget \
	&& rm -rf /var/lib/apt/lists/*

ENV LITECOIN_VERSION 0.21.5.4
ENV LITECOIN_URL https://download.litecoin.org/litecoin-${LITECOIN_VERSION}/litecoin-${LITECOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV LITECOIN_SHA256 91621306bafcadeebc266c264c95576536b5b2658e0ba03b05262ed4b9ab611f

# install litecoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO litecoin.tar.gz "$LITECOIN_URL" \
	&& echo "$LITECOIN_SHA256 litecoin.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf litecoin.tar.gz -C /tmp/bin --strip-components=2 "litecoin-$LITECOIN_VERSION/bin/litecoin-cli" "litecoin-$LITECOIN_VERSION/bin/litecoind" "litecoin-$LITECOIN_VERSION/bin/litecoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.19/gosu-amd64" \
	&& echo "52c8749d0142edd234e9d6bd5237dff2d81e71f43537e2f4f66f75dd4b243dd0 gosu" | sha256sum -c -

FROM debian:bookworm-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

RUN chmod +x /usr/local/bin/gosu && groupadd -r bitcoin && useradd -r -m -g bitcoin bitcoin

# create data directory
ENV BITCOIN_DATA /data
RUN mkdir "$BITCOIN_DATA" \
	&& chown -R bitcoin:bitcoin "$BITCOIN_DATA" \
	&& ln -sfn "$BITCOIN_DATA" /home/bitcoin/.litecoin \
	&& chown -h bitcoin:bitcoin /home/bitcoin/.litecoin
VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 9332 9333 19335 19332 19444 19332
CMD ["litecoind"]
