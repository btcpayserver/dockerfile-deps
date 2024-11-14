FROM  postgres:13.17

ENV PREVIOUS_VERSION 9.6
RUN cp /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list.backup && \
    sed -i "s/$/ $PREVIOUS_VERSION/" /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-$PREVIOUS_VERSION \
    postgresql-contrib-$PREVIOUS_VERSION && \
    rm /etc/apt/sources.list.d/pgdg.list && mv /etc/apt/sources.list.d/pgdg.list.backup /etc/apt/sources.list.d/pgdg.list && \
    rm -rf /var/lib/apt/lists/*

COPY migrate-docker-entrypoint.sh /migrate-docker-entrypoint.sh

ENTRYPOINT ["/migrate-docker-entrypoint.sh"]
CMD ["postgres"]