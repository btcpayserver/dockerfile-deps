FROM debian:bookworm-slim AS builder

# Set SHELL options per https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install build dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install -qq --no-install-recommends ca-certificates wget bzip2

# Set version-specific variables
ARG TARGETPLATFORM
ENV MONERO_VERSION=0.18.4.0

# Select binary based on build architecture
RUN case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            ARCH="x64" \
            CHECKSUM="16cb74c899922887827845a41d37c7f3121462792a540843f2fcabcc1603993f" \
            ;; \
        "linux/arm64") \
            ARCH="armv8" \
            CHECKSUM="f252b6a24e801535bf36fbaaa7b2d6ae44b1efc5d427803d483e3c3a17d6f2cd" \
            ;; \
        "linux/arm/v7") \
            ARCH="armv7" \
            CHECKSUM="b35b5e8d27d799cea6cf3ff539a672125292784739db41181b92a9c73e1c325b" \
            ;; \
    esac && \
    export FILE=monero-linux-${ARCH}-v${MONERO_VERSION}.tar.bz2 && \
    cd /tmp && \
    wget -qO ${FILE} https://downloads.getmonero.org/cli/${FILE} && \
    echo "${CHECKSUM} ${FILE}" | sha256sum -c - && \
    mkdir -p bin && \
    tar -jxf ${FILE} -C bin --strip-components=1 && \
    find bin/ -type f -executable -exec chmod a+x {} \;

# Final image
FROM debian:bookworm-slim

# Set SHELL options for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy binaries from builder stage
COPY --from=builder /tmp/bin/ /usr/local/bin/

# Define user and group IDs
ARG MONERO_USER_ID=999
ARG MONERO_GROUP_ID=999

# Install runtime dependencies
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -qq --no-install-recommends ca-certificates curl gosu \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Copy notifier script
COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x

# Create monero user with fixed ID
RUN groupadd -r -g $MONERO_GROUP_ID monero && \
    useradd -r -m -u $MONERO_USER_ID -g monero monero

# Create data directories
ENV MONERO_DATA=/home/monero/.bitmonero
ENV MONERO_WALLET=/wallet
RUN mkdir -p "$MONERO_DATA" "$MONERO_WALLET" && \
    chown -R monero:monero "$MONERO_DATA" "$MONERO_WALLET" && \
    chown -R monero:monero /home/monero

# Specify necessary volumes
VOLUME /home/monero/.bitmonero
VOLUME /wallet

# Expose p2p, RPC, and ZMQ ports
EXPOSE 18080
EXPOSE 18081
EXPOSE 18082

# Copy entrypoint script
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]