FROM python:3.9.7-slim-bullseye

RUN apt-get update && \
    apt-get install -qq --no-install-recommends curl tini sudo procps \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev python3-dev virtualenv python3-pip && \
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
    (python wallet-tool.py generate || true) \
    && cp "${CONFIG}" "${DEFAULT_CONFIG}"
WORKDIR /src/scripts
COPY docker-entrypoint.sh .
COPY *.sh ./
ENV PATH /src/scripts:$PATH
ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]