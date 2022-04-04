FROM debian:stretch-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV ELEMENTS_VERSION 0.21.0.2
ENV ELEMENTS_URL https://github.com/ElementsProject/elements/releases/download/elements-0.21.0.2/elements-elements-0.21.0.2-x86_64-linux-gnu.tar.gz
ENV ELEMENTS_SHA256 3018116794429b77ce0dd7436c2906f8be4eb5d6163b8451c5ce7e7bedad152b

# install elements binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO elements.tar.gz "$ELEMENTS_URL" \
	&& echo "$ELEMENTS_SHA256 elements.tar.gz" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf elements.tar.gz -C /tmp/bin --strip-components=2 "elements-elements-$ELEMENTS_VERSION/bin/elements-cli" "elements-elements-$ELEMENTS_VERSION/bin/elementsd" "elements-elements-$ELEMENTS_VERSION/bin/elements-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" \
	&& echo "0b843df6d86e270c5b0f5cbd3c326a04e18f4b7f9b8457fa497b0454c4b138d7 gosu" | sha256sum -c -

FROM debian:stretch-slim
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