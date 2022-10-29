# Use manifest image which support all architecture
FROM debian:stretch-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget

ENV DASH_VERSION 18.1.0
ENV DASH_URL https://github.com/dashpay/dash/releases/download/v${DASH_VERSION}/dashcore-${DASH_VERSION}-aarch64-linux-gnu.tar.gz
ENV DASH_SHA256 3ad6125a67cb76d195c9bae778e5a717e98436b98951a819411671d05aadc2ce
ENV DASH_ASC_URL https://github.com/dashpay/dash/releases/download/v${DASH_VERSION}/SHA256SUMS.asc
ENV DASH_PGP_KEY 52527BEDABE87984

# install dash binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO dash.tar.gz "$DASH_URL" \
	&& echo "$DASH_SHA256 dash.tar.gz" | sha256sum -c - \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys "$DASH_PGP_KEY" \
	&& wget -qO dash.asc "$DASH_ASC_URL" \
	&& gpg --verify dash.asc \
	&& mkdir bin \
	&& tar -xzvf dash.tar.gz -C /tmp/bin --strip-components=2 "dashcore-$DASH_VERSION/bin/dash-cli" "dashcore-$DASH_VERSION/bin/dashd" \
	&& cd bin \
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-arm64" \
	&& echo "5e279972a1c7adee65e3b5661788e8706594b458b7ce318fecbd392492cc4dbd gosu" | sha256sum -c -

# Making sure the builder build an arm image despite being x64
FROM arm64v8/debian:stretch-slim

COPY --from=builder "/tmp/bin" /usr/local/bin
#EnableQEMU COPY qemu-aarch64-static /usr/bin

RUN chmod +x /usr/local/bin/gosu && groupadd -r bitcoin && useradd -r -m -g bitcoin bitcoin

# create data directory
ENV BITCOIN_DATA /data
RUN mkdir "$BITCOIN_DATA" \
	&& chown -R bitcoin:bitcoin "$BITCOIN_DATA" \
	&& ln -sfn "$BITCOIN_DATA" /home/bitcoin/.dashcore \
	&& chown -h bitcoin:bitcoin /home/bitcoin/.dashcore

VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 9998 9999 19998 19999
CMD ["dashd"]
