FROM debian:bullseye-slim as builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static

FROM arm32v7/python:3.9.7-slim-bullseye as cryptographybuilder


#COPY --from=builder /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
#RUN apt-get update && apt-get install -qq --no-install-recommends build-essential libssl-dev libffi-dev rustc
#RUN pip install cryptography==3.3.2

RUN apt-get update && apt-get install -qq --no-install-recommends wget

# We use a prebuilt image, because our builder on circleci timeout after 1H and the build take too long
ENV CRYPTO_TAR="cryptography-3.3.2-pip-arm32v7.tar"
RUN mkdir -p /root/.cache && cd /root/.cache && \
    wget -qO ${CRYPTO_TAR} "https://aois.blob.core.windows.net/public/${CRYPTO_TAR}" && \
    echo "c7dde603057aaa0cb35582dba59ad487262e7f562640867545b1960afaf4f2e4 ${CRYPTO_TAR}" | sha256sum -c - && \
    tar -xvf "${CRYPTO_TAR}" && \
    rm "${CRYPTO_TAR}"

FROM arm32v7/python:3.9.7-slim-bullseye

COPY --from=builder /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
COPY --from=cryptographybuilder /root/.cache /root/.cache

RUN apt-get update && apt-get install -qq --no-install-recommends curl tini sudo procps vim git iproute2 \
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
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
ENV ENV_FILE "${DATADIR}/.env"
RUN . jmvenv/bin/activate && cd /src/scripts && \
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