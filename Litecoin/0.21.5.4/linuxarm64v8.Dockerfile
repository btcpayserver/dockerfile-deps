# Use manifest image which support all architecture
FROM debian:bookworm-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget qemu-user-static binfmt-support

ENV LITECOIN_VERSION 0.21.5.4
ENV LITECOIN_URL https://download.litecoin.org/litecoin-${LITECOIN_VERSION}/litecoin-${LITECOIN_VERSION}-aarch64-linux-gnu.tar.gz
ENV LITECOIN_SHA256 f0213853817d0ba7854aa718dc43bf991aba80a7db8b47969ae979dc083acce2

# install litecoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO litecoin.tar.gz "$LITECOIN_URL" \
	&& echo "$LITECOIN_SHA256 litecoin.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf litecoin.tar.gz -C /tmp/bin --strip-components=2 "litecoin-$LITECOIN_VERSION/bin/litecoin-cli" "litecoin-$LITECOIN_VERSION/bin/litecoind" "litecoin-$LITECOIN_VERSION/bin/litecoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.19/gosu-arm64" \
	&& echo "3a8ef022d82c0bc4a98bcb144e77da714c25fcfa64dccc57f6aba7ae47ff1a44 gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM --platform=arm64 debian:bookworm-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

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
