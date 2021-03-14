FROM python:3.7.10-stretch as qemu
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

# Dockerfile to build docker-compose for aarch64
FROM arm32v7/python:3.7.10-stretch as builder
# Add env
ENV LANG C.UTF-8

COPY --from=qemu /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update && apt-get install -qq --no-install-recommends unzip

# Set the versions
ENV DOCKER_COMPOSE_VER 1.28.5
# docker-compose requires pyinstaller (check github.com/docker/compose/requirements-build.txt)
# If this changes, you may need to modify the version of "six" below
ENV PYINSTALLER_VER 4.1
# "six" is needed for PyInstaller.
ENV SIX_VER 1.15.0

# Install dependencies
# RUN apt-get update && apt-get install -y
RUN pip install --upgrade pip
RUN pip install six==$SIX_VER

# Compile the pyinstaller "bootloader"
# https://pyinstaller.readthedocs.io/en/stable/bootloader-building.html
WORKDIR /build/pyinstallerbootloader
RUN curl -fsSL https://github.com/pyinstaller/pyinstaller/releases/download/v$PYINSTALLER_VER/PyInstaller-$PYINSTALLER_VER.tar.gz | tar xvz >/dev/null \
    && cd pyinstaller-$PYINSTALLER_VER/bootloader \
    && python3.7 waf configure all && cd .. && python3.7 -m pip install .

# Clone docker-compose
WORKDIR /build/dockercompose
RUN curl -fsSL https://github.com/docker/compose/archive/$DOCKER_COMPOSE_VER.zip > $DOCKER_COMPOSE_VER.zip \
    && unzip $DOCKER_COMPOSE_VER.zip

RUN cd compose-$DOCKER_COMPOSE_VER \
    && echo "unknown" > compose/GITSHA \
    && pyinstaller docker-compose.spec \
    && mkdir /dist \
    && mv dist/docker-compose /dist/docker-compose

FROM arm32v7/debian:stretch-slim

COPY --from=builder /dist/docker-compose /tmp/docker-compose

# Copy out the generated binary
VOLUME /dist
CMD /bin/cp /tmp/docker-compose /dist/docker-compose