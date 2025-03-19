# Use manifest image which support all architecture
FROM arm64v8/debian:bookworm-slim

RUN groupadd -r dogecoin && useradd -r -m -g dogecoin dogecoin

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget \
	&& rm -rf /var/lib/apt/lists/*

ENV DOGECOIN_VERSION 1.14.9
ENV DOGECOIN_URL https://github.com/dogecoin/dogecoin/releases/download/v1.14.9/dogecoin-1.14.9-aarch64-linux-gnu.tar.gz
ENV DOGECOIN_SHA256 6928c895a20d0bcb6d5c7dcec753d35c884a471aaf8ad4242a89a96acb4f2985

# install Dogecoin binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO dogecoin.tar.gz "$DOGECOIN_URL" \
	&& echo "$DOGECOIN_SHA256 dogecoin.tar.gz" | sha256sum -c - \
	&& tar -xzvf dogecoin.tar.gz -C /usr/local --strip-components=1 --exclude=*-qt \
	&& rm -rf /tmp/*

# create data directory
ENV DOGECOIN_DATA /data
RUN mkdir "$DOGECOIN_DATA" \
	&& chown -R dogecoin:dogecoin "$DOGECOIN_DATA" \
	&& ln -sfn "$DOGECOIN_DATA" /home/dogecoin/.dogecoin \
	&& chown -h dogecoin:dogecoin /home/dogecoin/.dogecoin
VOLUME /data

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5222 5223 25222 25223 25222 25223
CMD ["dogecoind"] 