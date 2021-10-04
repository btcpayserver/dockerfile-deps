FROM debian:bullseye-slim as builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static

FROM arm64v8/python:3.9.7-slim-bullseye

COPY --from=builder /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update && \
    apt-get install -qq --no-install-recommends curl tini sudo procps vim supervisor \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev python3-dev virtualenv python3-pip supervisor && \
    rm -rf /var/lib/apt/lists/*

ENV JM_VERSION 0.9.1
ENV JM_FILENAME v${JM_VERSION}.tar.jz

WORKDIR /src
RUN curl -fsSL "https://codeload.github.com/JoinMarket-Org/joinmarket-clientserver/tar.gz/refs/tags/v${JM_VERSION}" > "${JM_FILENAME}" && \
    tar  --strip-components=1 -xvf "${JM_FILENAME}" && rm "${JM_FILENAME}"

RUN ./install.sh
ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV ENV_FILE "${DATADIR}/.env"
RUN . jmvenv/bin/activate && cd /src/scripts && \
    pip install matplotlib && \
    (python wallet-tool.py generate || true) \
    && cp "${CONFIG}" "${DEFAULT_CONFIG}"
WORKDIR /src/scripts
COPY docker-entrypoint.sh .
COPY *.sh ./
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/
ENV PATH /src/scripts:$PATH
EXPOSE 62601
ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]