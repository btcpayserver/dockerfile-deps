FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV ELEMENTS_VERSION 23.2.4
ENV ELEMENTS_URL https://github.com/ElementsProject/elements/releases/download/elements-23.2.4/elements-23.2.4-x86_64-linux-gnu.tar.gz
ENV ELEMENTS_SHA256 6e0c747ec4ba4e54eb3426e7219354b5ea150b393a4e2b8a536cab64a5d9c7a8

# install elements binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO elements.tar.gz "$ELEMENTS_URL" \
	&& echo "$ELEMENTS_SHA256 elements.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf elements.tar.gz -C /tmp/bin --strip-components=2 "elements-$ELEMENTS_VERSION/bin/elements-cli" "elements-$ELEMENTS_VERSION/bin/elementsd" "elements-$ELEMENTS_VERSION/bin/elements-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" \
	&& echo "bbc4136d03ab138b1ad66fa4fc051bafc6cc7ffae632b069a53657279a450de3 gosu" | sha256sum -c -

FROM debian:buster-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

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
