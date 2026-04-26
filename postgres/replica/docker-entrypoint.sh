#!/bin/bash
set -e

# =============================================================================
# Entrypoint для PostgreSQL 16 Replica (Standby)
# =============================================================================

# Если данных нет — выполняем pg_basebackup с Primary
if [ -z "$(ls -A "$PGDATA" 2>/dev/null)" ]; then
    echo "============================================================"
    echo "Инициализация PostgreSQL 16 Replica"
    echo "============================================================"

    # Ожидание доступности Primary
    echo "Ожидание Primary ($PRIMARY_HOST:$PRIMARY_PORT)..."
    until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; do
        echo "Primary недоступен, ожидание..."
        sleep 2
    done
    echo "Primary доступен."

    # Пароль для pg_basebackup и WAL receiver
    export PGPASSWORD="$REPLICATOR_PASSWORD"

    # Создаём .pgpass для автоматического переподключения WAL receiver
    mkdir -p ~/.postgresql
    echo "*:*:*:replicator:$REPLICATOR_PASSWORD" > ~/.pgpass
    chmod 600 ~/.pgpass

    # Выполнение pg_basebackup без -R (создадим standby.signal и primary_conninfo вручную)
    echo "Выполнение pg_basebackup..."
    pg_basebackup \
        -h "$PRIMARY_HOST" \
        -p "$PRIMARY_PORT" \
        -U replicator \
        -D "$PGDATA" \
        -Fp \
        -Xs \
        -P \
        -v \
        -S replica_slot

    # Настройка standby
    touch "$PGDATA/standby.signal"

    cat >> "$PGDATA/postgresql.conf" <<EOF
# Standby settings
hot_standby = on
wal_receiver_status_interval = 10s
EOF

    # primary_conninfo с паролем для автоматического переподключения
    cat > "$PGDATA/postgresql.auto.conf" <<EOF
primary_conninfo = 'host=$PRIMARY_HOST port=$PRIMARY_PORT user=replicator password=$REPLICATOR_PASSWORD application_name=replica1'
EOF

    # Права доступа
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"

    echo "Replica инициализирована."
fi

exec "$@"
