# =============================================================================
# PostgreSQL 16 Replica (Standby) — потоковая репликация
# =============================================================================
FROM postgres:16

ENV POSTGRES_PASSWORD=postgres_password
ENV REPLICATOR_PASSWORD=repl_password
ENV PRIMARY_HOST=postgres-primary
ENV PRIMARY_PORT=5432

COPY replica/init-replica.sh /usr/local/bin/init-replica.sh
COPY replica/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/init-replica.sh /usr/local/bin/docker-entrypoint.sh

USER postgres

EXPOSE 5432

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres", "-c", "config_file=/var/lib/postgresql/data/postgresql.conf"]
