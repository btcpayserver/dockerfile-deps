FROM debian:trixie-slim

ENV BELDEX_VERSION=7.0.0
ENV BELDEX_DATA=/data
ENV BELDEX_WALLET=/wallet

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Download and extract Beldex binaries
RUN set -eux; \
    cd /tmp; \
    curl -L -o beldex.zip \
      https://github.com/Beldex-Coin/beldex/releases/download/v${BELDEX_VERSION}/beldex-linux-x86_64-v${BELDEX_VERSION}.zip; \
    unzip beldex.zip; \
    cp beldex-linux-x86_64-v${BELDEX_VERSION}/beldexd /usr/local/bin/; \
    cp beldex-linux-x86_64-v${BELDEX_VERSION}/beldex-wallet-cli /usr/local/bin/; \
    cp beldex-linux-x86_64-v${BELDEX_VERSION}/beldex-wallet-rpc /usr/local/bin/; \
    chmod +x /usr/local/bin/beldex*; \
    rm -rf /tmp/*

# Create beldex user
ARG BELDEX_USER_ID=980
ARG BELDEX_GROUP_ID=980
RUN groupadd -g ${BELDEX_GROUP_ID} beldex \
    && useradd -u ${BELDEX_USER_ID} -g beldex -m beldex

# Copy notifier script
COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x

# Create data directories
RUN mkdir -p ${BELDEX_DATA} ${BELDEX_WALLET} \
    && chown -R beldex:beldex ${BELDEX_DATA} ${BELDEX_WALLET}

VOLUME ["/data", "/wallet"]

# P2P + RPC
EXPOSE 19090 19091

COPY ./scripts/docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]