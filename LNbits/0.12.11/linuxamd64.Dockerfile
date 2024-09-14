FROM python:3.10-slim-bookworm AS builder

ENV REPO https://github.com/lnbits/lnbits
ENV REPO_REF v0.12.11

RUN apt-get clean
RUN apt-get update
RUN apt-get install -y curl pkg-config build-essential git libnss-myhostname

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

RUN git clone "$REPO" . --depth=1 --branch "$REPO_REF" && git checkout "$REPO_REF"

# Only copy the files required to install the dependencies
# not needed since we cloned the entire repo into builder already
# COPY pyproject.toml poetry.lock ./

RUN mkdir data

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

RUN poetry install --only main

FROM python:3.10-slim-bookworm

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

COPY --from=builder /app/.venv .venv

RUN mkdir data

RUN poetry install --only main

# hardcoded so we can ommit the sh in CMD that was used in upstream lnbits Dockerfile
#ENV LNBITS_PORT="5000"
#ENV LNBITS_HOST="0.0.0.0"

EXPOSE 5000

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY wait-for-it.sh /wait-for-it.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
