FROM  postgres:18.1

ENV PREVIOUS_VERSION 13
RUN cp /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list.backup && \
    sed -i "s/$/ $PREVIOUS_VERSION/" /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-$PREVIOUS_VERSION \
    postgresql-contrib-$PREVIOUS_VERSION && \
    rm /etc/apt/sources.list.d/pgdg.list && mv /etc/apt/sources.list.d/pgdg.list.backup /etc/apt/sources.list.d/pgdg.list && \
    rm -rf /var/lib/apt/lists/*

COPY scripts /scripts
ENTRYPOINT ["/scripts/migrate-docker-entrypoint.sh"]
CMD ["postgres"]