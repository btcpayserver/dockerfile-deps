FROM debian:buster-slim as builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static

FROM arm64v8/python:3.8.1-slim-buster

COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV EPS_VERSION 0.2.2
ENV EPS_SHA256 527cc6a8da1f17e2ec4ab4e0e712f002347c307328e794286760c7e34cfb9f2c

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