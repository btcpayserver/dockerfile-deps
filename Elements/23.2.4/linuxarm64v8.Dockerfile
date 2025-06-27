# Use manifest image which support all architecture
FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV ELEMENTS_VERSION 23.2.4
ENV ELEMENTS_URL https://github.com/ElementsProject/elements/releases/download/elements-23.2.4/elements-23.2.4-aarch64-linux-gnu.tar.gz
ENV ELEMENTS_SHA256 5c6f8219fd1baf4d4c2b05b6dd9ec71bb348754bd46aeb3faa7ba0ba69aff0e8

# install elements binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO elements.tar.gz "$ELEMENTS_URL" \
	&& echo "$ELEMENTS_SHA256 elements.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf elements.tar.gz -C /tmp/bin --strip-components=2 "elements-$ELEMENTS_VERSION/bin/elements-cli" "elements-$ELEMENTS_VERSION/bin/elementsd" "elements-$ELEMENTS_VERSION/bin/elements-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-arm64" \
	&& echo "c3805a85d17f4454c23d7059bcb97e1ec1af272b90126e79ed002342de08389b gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm64v8/debian:buster-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
#EnableQEMU COPY qemu-aarch64-static /usr/bin

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
