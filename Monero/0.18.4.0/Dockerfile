FROM debian:trixie-slim AS builder

# Install dependencies
RUN apt-get update && apt-get -y --no-install-recommends install bzip2 ca-certificates wget

# Set necessary variables for the current Monero version
ARG TARGETPLATFORM
ENV MONERO_VERSION=0.18.4.0

# Select and download binary based on build architecture
RUN set -ex \
    && case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            ARCH="x64" \
            FILE_CHECKSUM="16cb74c899922887827845a41d37c7f3121462792a540843f2fcabcc1603993f" \
            ;; \
        "linux/arm64") \
            ARCH="armv8" \
            FILE_CHECKSUM="f252b6a24e801535bf36fbaaa7b2d6ae44b1efc5d427803d483e3c3a17d6f2cd" \
            ;; \
        "linux/arm/v7") \
            ARCH="armv7" \
            FILE_CHECKSUM="b35b5e8d27d799cea6cf3ff539a672125292784739db41181b92a9c73e1c325b" \
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
	&& find bin/ -type f -executable -exec chmod a+x {} \;

FROM debian:trixie-slim
COPY --from=builder "/tmp/bin" /usr/local/bin

RUN apt-get update && apt-get -y --no-install-recommends install gosu && rm -rf /var/lib/apt/lists/*

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