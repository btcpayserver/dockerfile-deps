FROM python:3.9.7-slim-bullseye

RUN apt-get update && \
    apt-get install -qq --no-install-recommends gnupg curl tini sudo procps vim git iproute2 \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev \
    python3-dev python3-pip python3-venv virtualenv supervisor && \
    rm -rf /var/lib/apt/lists/*

ENV REPO https://github.com/JoinMarket-Org/joinmarket-clientserver
ENV REPO_REF v0.9.8

WORKDIR /src
RUN git clone "$REPO" . --depth=10 --branch "$REPO_REF" && git checkout "$REPO_REF"

RUN ./install.sh --disable-secp-check --without-qt
ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
ENV ENV_FILE "${DATADIR}/.env"
RUN python -m venv jmvenv && \
    . jmvenv/bin/activate && cd /src/scripts && \
    python -m pip install --upgrade pip && \
    pip install matplotlib && \
    (python wallet-tool.py generate || true) \
    && cp "${CONFIG}" "${DEFAULT_CONFIG}"
WORKDIR /src/scripts
COPY docker-entrypoint.sh .
COPY *.sh ./
COPY autostart /root/
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/
ENV PATH /src/scripts:$PATH
# jmwallet daemon
EXPOSE 28183
# jmwallet websocket
EXPOSE 28283
# payjoin server
EXPOSE 8080
# obwatch
EXPOSE 62601
ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]
