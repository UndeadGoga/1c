# =============================================================================
# PostgreSQL 16 Primary (на основе официального образа)
# =============================================================================
FROM postgres:16

ENV POSTGRES_PASSWORD=postgres_password
ENV REPLICATOR_PASSWORD=repl_password
ENV PGDATA=/var/lib/postgresql/data

# Копирование конфигурации (под root, затем меняем права)
COPY primary/postgresql.conf /tmp/postgresql.conf
COPY primary/pg_hba.conf /tmp/pg_hba.conf
COPY primary/init-primary.sh /usr/local/bin/init-primary.sh
COPY primary/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/init-primary.sh /usr/local/bin/docker-entrypoint.sh \
    && chown postgres:postgres /tmp/postgresql.conf /tmp/pg_hba.conf

USER postgres

EXPOSE 5432

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres", "-c", "config_file=/var/lib/postgresql/data/postgresql.conf"]
