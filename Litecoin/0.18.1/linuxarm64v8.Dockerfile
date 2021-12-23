# Use manifest image which support all architecture
FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV LITECOIN_VERSION 0.18.1
ENV LITECOIN_URL https://download.litecoin.org/litecoin-${LITECOIN_VERSION}/linux/litecoin-${LITECOIN_VERSION}-aarch64-linux-gnu.tar.gz
ENV LITECOIN_SHA256 e0bdd4aa81502551a0c5abcfaae52c8bbaf4a980548aa6c91053643d81924b51

# install litecoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO litecoin.tar.gz "$LITECOIN_URL" \
	&& echo "$LITECOIN_SHA256 litecoin.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf litecoin.tar.gz -C /tmp/bin --strip-components=2 "litecoin-$LITECOIN_VERSION/bin/litecoin-cli" "litecoin-$LITECOIN_VERSION/bin/litecoind" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" \
	&& echo "73244a858f5514a927a0f2510d533b4b57169b64d2aa3f9d98d92a7a7df80cea gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm64v8/debian:buster-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
#EnableQEMU COPY qemu-arm-static /usr/bin

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
