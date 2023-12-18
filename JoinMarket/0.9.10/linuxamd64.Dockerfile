FROM python:3.9-slim-bookworm

ENV REPO https://github.com/JoinMarket-Org/joinmarket-clientserver
ENV REPO_REF v0.9.10

ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
ENV ENV_FILE "${DATADIR}/.env"

# install dependencies
RUN apt-get update
RUN apt-get install -qq --no-install-recommends curl tini procps vim git iproute2 gnupg supervisor \
    build-essential automake pkg-config libtool libffi-dev libssl-dev libgmp-dev libltdl-dev libsodium-dev \
    python3-dev python3-pip python3-setuptools python3-venv

# install joinmarket
WORKDIR /src
RUN git clone "$REPO" . --depth=1 --branch "$REPO_REF" && git checkout "$REPO_REF"
RUN ./install.sh --docker-install --without-qt
RUN pip install matplotlib

# setup
WORKDIR /src/scripts
RUN (python wallet-tool.py generate || true) && cp "${CONFIG}" "${DEFAULT_CONFIG}"
COPY *.sh ./
COPY autostart /root/
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/
ENV PATH /src/scripts:$PATH

# cleanup and remove ephemeral dependencies
RUN rm --recursive --force install.sh deps/cache/ test/ .git/ .gitignore .github/ .coveragerc joinmarket-qt.desktop
RUN apt-get remove --purge --auto-remove -y gnupg python3-pip apt-transport-https && apt-get clean
RUN rm -rf /var/lib/apt/lists/* /var/log/dpkg.log

# jmwallet daemon
EXPOSE 28183
# payjoin server
EXPOSE 8080
# obwatch
EXPOSE 62601
ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]
