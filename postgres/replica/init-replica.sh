#!/bin/bash
set -e

# =============================================================================
# Инициализация PostgreSQL Replica (Standby)
# =============================================================================

echo "============================================================"
echo "Настройка PostgreSQL Replica (Standby)"
echo "============================================================"

# Ожидание доступности Primary
echo "Ожидание Primary ($PRIMARY_HOST:$PRIMARY_PORT)..."
until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$POSTGRES_USER"; do
    echo "Primary недоступен, ожидание..."
    sleep 2
done
echo "Primary доступен."

# Очистка старых данных
rm -rf "$PGDATA"/*

# Выполнение pg_basebackup с Primary
echo "Выполнение pg_basebackup с $PRIMARY_HOST..."
pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p "$PRIMARY_PORT" \
    -U replicator \
    -D "$PGDATA" \
    -Fp \
    -Xs \
    -P \
    -v \
    -R \
    -S replica_slot \
    -W

# Настройка postgresql.conf для standby
cat >> "$PGDATA/postgresql.conf" <<EOF
# Standby settings
hot_standby = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
EOF

# Настройка recovery.signal для PostgreSQL 12+
touch "$PGDATA/standby.signal"

# Настройка primary_conninfo
cat > "$PGDATA/postgresql.auto.conf" <<EOF
primary_conninfo = 'host=$PRIMARY_HOST port=$PRIMARY_PORT user=replicator password=$REPLICATOR_PASSWORD application_name=replica1'
EOF

# Права доступа
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

echo "============================================================"
echo "Replica настроена. Подключение к Primary: $PRIMARY_HOST:$PRIMARY_PORT"
echo "============================================================"
