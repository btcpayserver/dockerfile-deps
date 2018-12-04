FROM debian:stretch-slim as builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget

ENV DASH_VERSION 0.12.3
ENV DASH_URL https://github.com/dashpay/dash/releases/download/v0.12.3.3/dashcore-0.12.3.3-x86_64-linux-gnu.tar.gz
ENV DASH_SHA256 19191193a8eaf5a10be08eaa3f33ea60c6a2b8848cd8cfeb8aa2046c962b32bd
ENV DASH_ASC_URL https://github.com/dashpay/dash/releases/download/v0.12.3.3/SHA256SUMS.asc
ENV DASH_PGP_KEY 83592BD1400D58D9

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
