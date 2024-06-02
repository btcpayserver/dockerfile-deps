FROM python:3.10-slim-bookworm

ENV REPO https://github.com/lnbits/lnbits
ENV REPO_REF 0.12.8

RUN apt-get clean
RUN apt-get update
RUN apt-get install -y curl pkg-config build-essential git libnss-myhostname

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

# needed for backups postgresql-client version 14 (pg_dump)
RUN apt install -y postgresql-common ca-certificates xxd
RUN install -d /usr/share/postgresql-common/pgdg
RUN curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN apt-get update
RUN apt-get install -y postgresql-client-14

WORKDIR /app

RUN git clone "$REPO" . --depth=1 --branch "$REPO_REF" && git checkout "$REPO_REF"

RUN mkdir data

RUN poetry install --only main

# hardcoded so we can ommit the sh in CMD that was used in upstream lnbits Dockerfile
#ENV LNBITS_PORT="5000"
#ENV LNBITS_HOST="0.0.0.0"

EXPOSE 5000

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY wait-for-it.sh /wait-for-it.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
