FROM debian:bullseye-slim as builder
RUN apt-get update && apt-get install -qq --no-install-recommends qemu-user-static

FROM arm64v8/python:3.10-slim-bullseye
COPY --from=builder /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV REPO https://github.com/lnbits/lnbits
ENV REPO_REF 0.12.4

RUN apt-get clean
RUN apt-get update
RUN apt-get install -y curl pkg-config build-essential git libnss-myhostname

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

# needed for backups postgresql-client version 14 (pg_dump)
RUN apt-get install -y apt-utils wget
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
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

CMD ["poetry", "run", "lnbits", "--port", "5000", "--host", "0.0.0.0"]