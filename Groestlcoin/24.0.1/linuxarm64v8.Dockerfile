# Use manifest image which support all architecture
FROM debian:buster-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu wget
RUN apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

ENV GROESTLCOIN_VERSION 24.0.1
ENV GROESTLCOIN_TARBALL groestlcoin-${GROESTLCOIN_VERSION}-aarch64-linux-gnu.tar.gz
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v$GROESTLCOIN_VERSION/$GROESTLCOIN_TARBALL
ENV GROESTLCOIN_SHA256 ca316c369728348406778c30b2b567bb2ede1ebcc87fb0305c0bed3dacae762b

# install groestlcoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO $GROESTLCOIN_TARBALL "$GROESTLCOIN_URL" \
	&& echo "$GROESTLCOIN_SHA256 $GROESTLCOIN_TARBALL" | sha256sum -c - \
	&& mkdir bin \
	&& tar -xzvf $GROESTLCOIN_TARBALL -C /tmp/bin --strip-components=2 "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-cli" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoind" "groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin-wallet" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-arm64" \
	&& echo "5e279972a1c7adee65e3b5661788e8706594b458b7ce318fecbd392492cc4dbd gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm64v8/debian:buster-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

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
