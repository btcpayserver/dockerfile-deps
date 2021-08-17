# Use manifest image which support all architecture
FROM debian:stretch-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV ELEMENTS_VERSION 0.18.1.12
ENV ELEMENTS_URL https://github.com/ElementsProject/elements/releases/download/elements-0.18.1.12/elements-0.18.1.12-aarch64-linux-gnu.tar.gz
ENV ELEMENTS_SHA256 6d3f854169941a2aa536be04063ca373ffa09937c4e9be0bbcc8d6be30fd88ce

# install elements binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO elements.tar.gz "$ELEMENTS_URL" \
	&& echo "$ELEMENTS_SHA256 elements.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf elements.tar.gz -C /tmp/bin --strip-components=2 "elements-$ELEMENTS_VERSION/bin/elements-cli" "elements-$ELEMENTS_VERSION/bin/elementsd" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-arm64" \
	&& echo "5e279972a1c7adee65e3b5661788e8706594b458b7ce318fecbd392492cc4dbd gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm64v8/debian:stretch-slim

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