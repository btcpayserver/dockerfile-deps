# runtime stage
FROM debian:stretch-slim

# Set necessary environment variables
ENV FILE=monero-linux-x64-v0.17.2.0.tar.bz2
ENV FILE_CHECKSUM=59e16c53b2aff8d9ab7a8ba3279ee826ac1f2480fbb98e79a149e6be23dd9086

# Set SHELL options per https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN apt-get update \
    && apt-get -y --no-install-recommends install bzip2 ca-certificates wget curl \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/*

# Download specified Monero tar.gz
RUN wget -qO $FILE https://downloads.getmonero.org/cli/$FILE 

# Verify downloaded binary against hardcoded checksum
RUN echo "$FILE_CHECKSUM $FILE" | sha256sum -c - 

# Extract and set permissions on Monero binaries
RUN mkdir -p extracted 
RUN tar -jxvf $FILE -C /extracted 
RUN find /extracted/ -type f -print0 | xargs -0 chmod a+x
RUN find /extracted/ -type f -print0 | xargs -0 mv -t /usr/local/bin/
RUN rm -rf extracted && rm $FILE 

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