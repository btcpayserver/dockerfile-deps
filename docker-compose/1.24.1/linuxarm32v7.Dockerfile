FROM python:3.6.5-stretch as qemu
RUN apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

# Dockerfile to build docker-compose for aarch64
FROM arm32v7/python:3.6.5-stretch as builder
# Add env
ENV LANG C.UTF-8

COPY --from=builder /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update && apt-get install -qq --no-install-recommends unzip
RUN apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

# Set the versions
ENV DOCKER_COMPOSE_VER 1.24.1
# docker-compose requires pyinstaller 3.5 (check github.com/docker/compose/requirements-build.txt)
# If this changes, you may need to modify the version of "six" below
ENV PYINSTALLER_VER 3.5
# "six" is needed for PyInstaller. v1.11.0 is the latest as of PyInstaller 3.5
ENV SIX_VER 1.11.0

# Install dependencies
# RUN apt-get update && apt-get install -y
RUN pip install --upgrade pip
RUN pip install six==$SIX_VER

# Compile the pyinstaller "bootloader"
# https://pyinstaller.readthedocs.io/en/stable/bootloader-building.html
WORKDIR /build/pyinstallerbootloader
RUN curl -fsSL https://github.com/pyinstaller/pyinstaller/releases/download/v$PYINSTALLER_VER/PyInstaller-$PYINSTALLER_VER.tar.gz | tar xvz >/dev/null \
    && cd PyInstaller*/bootloader \
    && python3 ./waf all

# Clone docker-compose
WORKDIR /build/dockercompose
RUN curl -fsSL https://github.com/docker/compose/archive/$DOCKER_COMPOSE_VER.zip > $DOCKER_COMPOSE_VER.zip \
    && unzip $DOCKER_COMPOSE_VER.zip

# We need to patch pynacl because of https://github.com/pyca/pynacl/issues/553
COPY PyNaCl-remove-check.patch PyNaCl-remove-check.patch
RUN cd compose-$DOCKER_COMPOSE_VER && pip download --dest "/tmp/packages" -r requirements.txt -r requirements-build.txt wheel && cd .. && \
    wget -qO pynacl.tar.gz https://github.com/pyca/pynacl/archive/1.3.0.tar.gz && \
    echo "205adb2804eed4bc3780584e368ef2e9b8b22a7aae85323068cadd59f3c8a584  pynacl.tar.gz" | sha256sum -c - && \
    mkdir pynacl && tar --strip-components=1 -xvf pynacl.tar.gz -C pynacl && rm pynacl.tar.gz && \
    cd pynacl && \
    git apply ../PyNaCl-remove-check.patch && \
    python3 setup.py sdist && \
    cp -f dist/PyNaCl-1.3.0.tar.gz /tmp/packages/ && \
    cd ../compose-$DOCKER_COMPOSE_VER && rm -rf ../pynacl && \
    pip install --no-index --find-links /tmp/packages -r requirements.txt -r requirements-build.txt && rm -rf /tmp/packages

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