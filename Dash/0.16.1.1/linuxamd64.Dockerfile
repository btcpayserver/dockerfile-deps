FROM debian:stretch-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget

ENV DASH_VERSION 0.16.1
ENV DASH_URL https://github.com/dashpay/dash/releases/download/v0.16.1.1/dashcore-0.16.1.1-x86_64-linux-gnu.tar.gz
ENV DASH_SHA256 8803928bd18e9515f1254f97751eb6e537a084d66111ce7968eafb23e26bf3a5
ENV DASH_ASC_URL https://github.com/dashpay/dash/releases/download/v0.16.1.1/SHA256SUMS.asc
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
	&& wget -qO gosu "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" \
	&& echo "0b843df6d86e270c5b0f5cbd3c326a04e18f4b7f9b8457fa497b0454c4b138d7 gosu" | sha256sum -c -

FROM debian:stretch-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

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
