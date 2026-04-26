#!/bin/bash
set -e

# =============================================================================
# Entrypoint для PostgreSQL 16 Primary (1С-сборка)
# =============================================================================

# Поиск initdb (может быть в разных местах в сборке от 1С)
INITDB=$(which initdb 2>/dev/null || find /usr/lib/postgresql -name initdb -type f 2>/dev/null | head -n 1 || find /opt -name initdb -type f 2>/dev/null | head -n 1)
PGCTL=$(which pg_ctl 2>/dev/null || find /usr/lib/postgresql -name pg_ctl -type f 2>/dev/null | head -n 1 || find /opt -name pg_ctl -type f 2>/dev/null | head -n 1)
PSQL=$(which psql 2>/dev/null || find /usr/lib/postgresql -name psql -type f 2>/dev/null | head -n 1 || find /opt -name psql -type f 2>/dev/null | head -n 1)

if [ -z "$INITDB" ] || [ ! -x "$INITDB" ]; then
    echo "ОШИБКА: initdb не найден!"
    echo "Пути поиска:"
    find /usr -name initdb -type f 2>/dev/null || true
    find /opt -name initdb -type f 2>/dev/null || true
    exit 1
fi

echo "Используем initdb: $INITDB"

# Если данных нет — инициализируем
if [ -z "$(ls -A "$PGDATA" 2>/dev/null)" ]; then
    echo "============================================================"
    echo "Инициализация PostgreSQL 16 Primary"
    echo "============================================================"

    "$INITDB" -D "$PGDATA" -E UTF8 --locale=C.UTF-8

    # Копируем конфигурацию
    cp /tmp/postgresql.conf "$PGDATA/postgresql.conf"
    cp /tmp/pg_hba.conf "$PGDATA/pg_hba.conf"

    # Запускаем временно для настройки пользователей
    "$PGCTL" -D "$PGDATA" -o "-c listen_addresses=''" -w start

    "$PSQL" -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
        ALTER USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
        CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATOR_PASSWORD';
        CREATE USER usr1cv8 WITH PASSWORD '$POSTGRES_PASSWORD' SUPERUSER;
        CREATE DATABASE my_db OWNER usr1cv8 ENCODING 'UTF8' LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8';
EOSQL

    # Создание слота репликации
    "$PSQL" -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "SELECT pg_create_physical_replication_slot('replica_slot', true);" || true

    # Создание директории для WAL
    mkdir -p /backup/wal

    "$PGCTL" -D "$PGDATA" -m fast -w stop

    echo "Primary инициализирован."
fi

# Если есть init-скрипт — выполняем
if [ -x /usr/local/bin/init-primary.sh ]; then
    /usr/local/bin/init-primary.sh || true
fi

exec "$@"
