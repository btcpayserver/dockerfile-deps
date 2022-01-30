FROM debian:bullseye-slim as builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static

FROM arm64v8/python:3.9.7-slim-bullseye

COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static
RUN apt-get update && \
    apt-get install -qq --no-install-recommends curl tini sudo procps vim git iproute2 \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev python3-dev virtualenv python3-pip supervisor && \
    rm -rf /var/lib/apt/lists/*

ENV REPO https://github.com/JoinMarket-Org/joinmarket-clientserver
ENV REPO_REF v0.9.4

WORKDIR /src
RUN git clone "$REPO" . --depth=10 --branch "$REPO_REF" && git checkout "$REPO_REF"

RUN ./install.sh --disable-secp-check --without-qt
ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV ENV_FILE "${DATADIR}/.env"
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
RUN . jmvenv/bin/activate && cd /src/scripts && \
    pip install matplotlib && \
    (python wallet-tool.py generate || true) \
    && cp "${CONFIG}" "${DEFAULT_CONFIG}"
WORKDIR /src/scripts
COPY docker-entrypoint.sh .
COPY *.sh ./
COPY autostart /root/
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/
ENV PATH /src/scripts:$PATH
EXPOSE 62601 8080
ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]