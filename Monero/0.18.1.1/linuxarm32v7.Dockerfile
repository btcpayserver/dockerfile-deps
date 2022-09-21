# Explicitly specify arm32v7 base image
FROM arm32v7/debian:stretch-slim
#EnableQEMU COPY qemu-arm-static /usr/bin
# Set necessary environment variables for the current Monero version and hash
ENV FILE=monero-linux-armv7-v0.18.1.1.tar.bz2
ENV FILE_CHECKSUM=c8cbf9cdfb89f1b2c5f6599ceb715ece69bd99f9ce669953d6768d7c7aa6963b

# Set SHELL options per https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get -y --no-install-recommends install bzip2 ca-certificates wget curl \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/*

# Download specified Monero tar.gz and verify downloaded binary against hardcoded checksum
RUN wget -qO $FILE https://downloads.getmonero.org/cli/$FILE && \
    echo "$FILE_CHECKSUM $FILE" | sha256sum -c - 

# Extract and set permissions on Monero binaries
RUN mkdir -p extracted && \
    tar -jxvf $FILE -C /extracted && \
    find /extracted/ -type f -print0 | xargs -0 chmod a+x && \
    find /extracted/ -type f -print0 | xargs -0 mv -t /usr/local/bin/ && \
    rm -rf extracted && rm $FILE

# Copy notifier script
COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x

# Create monero user
RUN adduser --system --group --disabled-password monero && \
	mkdir -p /wallet /home/monero/.bitmonero && \
	chown -R monero:monero /home/monero/.bitmonero && \
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

# Add HEALTHCHECK against get_info endpoint
HEALTHCHECK --interval=5s --timeout=3s CMD curl --fail http://localhost:18081/get_info || exit 1
