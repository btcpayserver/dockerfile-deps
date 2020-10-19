# runtime stage
FROM debian:stretch-slim
ENV FILE=monero-linux-x64-v0.17.1.1.tar.bz2
ENV FILE_CHECKSUM=4113cc92314fefebe52024d67a8b5d6d499adb4c3988f5d2b838ed3f80893874
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


