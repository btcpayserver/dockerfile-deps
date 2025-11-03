FROM debian:trixie-slim AS builder

# Install dependencies
RUN apt-get update && apt-get -y --no-install-recommends install bzip2 ca-certificates wget

# Set necessary variables for the current Monero version
ARG TARGETPLATFORM
ENV MONERO_VERSION=0.18.4.3

# Select and download binary based on build architecture
RUN set -ex \
    && case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            ARCH="x64" \
            FILE_CHECKSUM="3a7b36ae4da831a4e9913e0a891728f4c43cd320f9b136cdb6686b1d0a33fafa" \
            TAR_PATH="monero-x86_64-linux-gnu-v${MONERO_VERSION}/" \
            ;; \
        "linux/arm64") \
            ARCH="armv8" \
            FILE_CHECKSUM="b1cc5f135de3ba8512d56deb4b536b38c41addde922b2a53bf443aeaf2a5a800" \
            TAR_PATH="monero-aarch64-linux-gnu-v${MONERO_VERSION}/" \
            ;; \
        "linux/arm/v7") \
            ARCH="armv7" \
            FILE_CHECKSUM="3ac83049bc565fb5238501f0fa629cdd473bbe94d5fb815088af8e6ff1d761cd" \
            TAR_PATH="monero-arm-linux-gnueabihf-v${MONERO_VERSION}/" \
            ;; \
        *) \
            echo "Unsupported architecture: ${TARGETPLATFORM}" \
            exit 1 \
            ;; \
    esac \
    && export FILE=monero-linux-${ARCH}-v${MONERO_VERSION}.tar.bz2 \
	&& cd /tmp \
	&& wget -qO ${FILE} https://downloads.getmonero.org/cli/${FILE} \
	&& echo "${FILE_CHECKSUM} ${FILE}" | sha256sum -c - \
	&& mkdir bin \
	&& tar -jxf ${FILE} -C bin --strip-components=1 \
        "${TAR_PATH}monero-wallet-cli" \
        "${TAR_PATH}monero-wallet-rpc" \
        "${TAR_PATH}monerod" \
	&& find bin/ -type f -executable -exec chmod a+x {} \;

FROM debian:trixie-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

RUN apt-get update && apt-get -y --no-install-recommends install gosu curl && rm -rf /var/lib/apt/lists/*

# Create user and group id for monero user
ARG MONERO_USER_ID=980
ARG MONERO_GROUP_ID=980

# Add monero user
RUN groupadd -r -g $MONERO_GROUP_ID monero && useradd -r -m -u $MONERO_USER_ID -g monero monero

# Copy notifier script
COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x

# Create data and wallet directories
ENV MONERO_DATA=/data
ENV MONERO_WALLET=/wallet
RUN mkdir -p "$MONERO_DATA" "$MONERO_WALLET" \
    && chown -R monero:monero "$MONERO_DATA" "$MONERO_WALLET" \
    && ln -sfn "$MONERO_DATA" /home/monero/.bitmonero \
    && chown -h monero:monero /home/monero/.bitmonero

# Specify necessary volumes
VOLUME /data
VOLUME /wallet

# Expose p2p, RPC, and ZMQ ports
EXPOSE 18080 18081 18082

COPY ./scripts/docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]