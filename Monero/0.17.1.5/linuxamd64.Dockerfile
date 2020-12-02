# runtime stage
FROM debian:stretch-slim
ENV FILE=monero-linux-x64-v0.17.1.5.tar.bz2
ENV FILE_CHECKSUM=95666508e695637830b4c1700538c717ff97f02f181fbb337a109763372c8d34
RUN apt-get update \
    && apt-get -y --no-install-recommends install bzip2 ca-certificates wget curl
RUN wget -qO $FILE https://downloads.getmonero.org/cli/$FILE 

RUN echo "$FILE_CHECKSUM $FILE" | sha256sum -c - 
RUN mkdir -p extracted 
RUN tar -jxvf $FILE -C /extracted 
RUN find /extracted/ -type f -print0 | xargs -0 chmod a+x
RUN find /extracted/ -type f -print0 | xargs -0 mv -t /usr/local/bin/
RUN rm -rf extracted && rm $FILE 
RUN apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/{apt,dpkg,cache,log}

COPY ./scripts /scripts/
RUN find /scripts/ -type f -print0 | xargs -0 chmod a+x
# Create monero user
RUN adduser --system --group --disabled-password monero && \
	mkdir -p /wallet /home/monero/.bitmonero && \
	chown -R monero:monero /home/monero/.bitmonero && \
	chown -R monero:monero /wallet

VOLUME /home/monero/.bitmonero
VOLUME /wallet

EXPOSE 18080
EXPOSE 18081
EXPOSE 18082
# switch to user monero
USER monero


