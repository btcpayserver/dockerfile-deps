FROM python:3.8.1-slim-buster

ENV EPS_VERSION 0.2.1.1
ENV EPS_SHA256 014ee376144c40a5b5c81405dc5713c5c6803b1a69f0525759a1e630de72269b

RUN apt-get update && \
    apt-get install -qq --no-install-recommends curl unzip wget tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
WORKDIR /tmp
RUN FILENAME="eps-v${EPS_VERSION}.zip" && \
    curl -fsSL "https://github.com/chris-belcher/electrum-personal-server/archive/$FILENAME" > "$FILENAME" && \
    echo "$EPS_SHA256 $FILENAME" | sha256sum -c - && \
    unzip "$FILENAME" && \
    DIRECTORY_NAME="electrum-personal-server-eps-v${EPS_VERSION}" && \
    mv "$DIRECTORY_NAME" "/build/eps" && rm "$FILENAME"

WORKDIR /build/eps
RUN pip3 install . && mkdir -p /data

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT  [ "tini", "-g", "--", "/docker-entrypoint.sh" ]
CMD [ "electrum-personal-server" ]