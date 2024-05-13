# Use manifest image which support all architecture
FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV ELEMENTS_VERSION 23.2.1
ENV ELEMENTS_URL https://github.com/ElementsProject/elements/releases/download/elements-23.2.1/elements-23.2.1-arm-linux-gnueabihf.tar.gz
ENV ELEMENTS_SHA256 9640e40685d25c7053a07ba5ad2319632a8d67bed5b2fbdc815163210b2bf0ff

# install elements binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO elements.tar.gz "$ELEMENTS_URL" \
	&& echo "$ELEMENTS_SHA256 elements.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf elements.tar.gz -C /tmp/bin --strip-components=2 "elements-$ELEMENTS_VERSION/bin/elements-cli" "elements-$ELEMENTS_VERSION/bin/elementsd" "elements-$ELEMENTS_VERSION/bin/elements-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-armhf" \
	&& echo "171b4a2decc920de0dd4f49278d3e14712da5fa48de57c556f99bcdabe03552e gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm32v7/debian:buster-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
#EnableQEMU COPY qemu-arm-static /usr/bin

RUN chmod +x /usr/local/bin/gosu && groupadd -r elements && useradd -r -m -g elements elements

# create data directory
ENV ELEMENTS_DATA /data
RUN mkdir "$ELEMENTS_DATA" \
	&& chown -R elements:elements "$ELEMENTS_DATA" \
	&& ln -sfn "$ELEMENTS_DATA" /home/elements/.elements \
	&& chown -h elements:elements /home/elements/.elements

VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]

EXPOSE 8332 8333 18332 18333 18443 18444
CMD ["elementsd"]
