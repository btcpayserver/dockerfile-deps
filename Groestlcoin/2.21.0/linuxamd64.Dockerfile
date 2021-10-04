FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget

ENV GROESTLCOIN_VERSION 2.21.0
ENV GROESTLCOIN_TARBALL groestlcoin-${GROESTLCOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v$GROESTLCOIN_VERSION/$GROESTLCOIN_TARBALL
ENV GROESTLCOIN_SHA256 cc01c2d8a3f5e6730e931fdc579658aff74d9618adadee095bea06da54e75d5b

# install groestlcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO $GROESTLCOIN_TARBALL "$GROESTLCOIN_URL" \
	&& echo "$GROESTLCOIN_SHA256 $GROESTLCOIN_TARBALL" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf $GROESTLCOIN_TARBALL -C /tmp/bin --strip-components=2 "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-cli" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoind" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" \
	&& echo "0b843df6d86e270c5b0f5cbd3c326a04e18f4b7f9b8457fa497b0454c4b138d7 gosu" | sha256sum -c -

FROM debian:buster-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

RUN chmod +x /usr/local/bin/gosu && groupadd -r groestlcoin && useradd -r -m -g groestlcoin groestlcoin

# create data directory
ENV GROESTLCOIN_DATA /data
RUN mkdir "$GROESTLCOIN_DATA" \
	&& chown -R groestlcoin:groestlcoin "$GROESTLCOIN_DATA" \
	&& ln -sfn "$GROESTLCOIN_DATA" /home/groestlcoin/.groestlcoin \
	&& chown -h groestlcoin:groestlcoin /home/groestlcoin/.groestlcoin

VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1331 1441 17777 17766 18888 18443 31331 31441
CMD ["groestlcoind"]
