# Use manifest image which supports all architectures
FROM debian:bookworm-slim AS builder

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates wget bzip2
RUN apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

ENV MONERO_VERSION=0.18.4.0
ENV FILE=monero-linux-armv8-v${MONERO_VERSION}.tar.bz2
ENV FILE_CHECKSUM=f252b6a24e801535bf36fbaaa7b2d6ae44b1efc5d427803d483e3c3a17d6f2cd

# Download and verify Monero binaries
RUN set -ex \
	&& cd /tmp \
	&& wget -qO ${FILE} https://downloads.getmonero.org/cli/${FILE} \
	&& echo "${FILE_CHECKSUM} ${FILE}" | sha256sum -c - \
	&& mkdir bin \
	&& tar -jxf ${FILE} -C bin --strip-components=1 \
	&& find bin/ -type f -executable -exec chmod +x {} \;

# Making sure the final image is ARM64 despite being built on x64
FROM --platform=arm64 debian:bookworm-slim

RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -qq --no-install-recommends ca-certificates curl \
	&& apt-get clean \
	&& apt-get autoclean \
	&& apt-get autoremove \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder "/tmp/bin" /usr/local/bin
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

# Copy notifier script
COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x

# Create monero user
RUN adduser --system --group --disabled-password monero && \
	mkdir -p /wallet /home/monero/.bitmonero && \
	chown -R monero:monero /home/monero/.bitmonero && \
	chown -R monero:monero /home/monero && \
	chown -R monero:monero /wallet

# Specify necessary volumes
VOLUME /home/monero/.bitmonero
VOLUME /wallet

# Expose p2p, RPC, and ZMQ ports
EXPOSE 18080
EXPOSE 18081
EXPOSE 18082
# Switch to user monero
USER monero
ENV HOME=/home/monero
