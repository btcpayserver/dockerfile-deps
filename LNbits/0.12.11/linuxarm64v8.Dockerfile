FROM debian:bookworm-slim AS builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static binfmt-support

FROM arm64v8/python:3.10.13-slim-bookworm AS builder2
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV REPO https://github.com/lnbits/lnbits
ENV REPO_REF v0.12.11

RUN apt-get clean
RUN apt-get update
RUN apt-get install -y curl pkg-config build-essential git libnss-myhostname

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# Only copy the files required to install the dependencies
# not needed since we cloned the entire repo into builder already
#COPY pyproject.toml poetry.lock ./
RUN git clone "$REPO" . --depth=1 --branch "$REPO_REF" && git checkout "$REPO_REF"

RUN mkdir data

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

RUN poetry install --only main

FROM arm64v8/python:3.10.13-slim-bookworm

COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV REPO https://github.com/lnbits/lnbits
ENV REPO_REF v0.12.11

# needed for backups postgresql-client version 14 (pg_dump)
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install xxd gnupg2 curl git lsb-release && \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get -y install postgresql-client-14 postgresql-client-common && \
    apt-get clean all && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

RUN git clone "$REPO" . --depth=1 --branch "$REPO_REF" && git checkout "$REPO_REF"

COPY --from=builder2 /app/.venv .venv

RUN mkdir data

RUN poetry install --only main

# hardcoded so we can ommit the sh in CMD that was used in upstream lnbits Dockerfile
#ENV LNBITS_PORT="5000"
#ENV LNBITS_HOST="0.0.0.0"

EXPOSE 5000

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY wait-for-it.sh /wait-for-it.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
