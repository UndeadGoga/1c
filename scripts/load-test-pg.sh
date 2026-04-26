#!/bin/bash
# =============================================================================
# Нагрузочное тестирование PostgreSQL через pgbench
# =============================================================================
set -euo pipefail

HOST="${PGHOST:-postgres-primary}"
PORT="${PGPORT:-5432}"
USER="${PGUSER:-postgres}"
PASS="${PGPASSWORD:-postgres_password}"
DB="${PGDATABASE:-my_db}"
SCALE="${SCALE:-10}"
CLIENTS="${CLIENTS:-10}"
TRANSACTIONS="${TRANSACTIONS:-1000}"

echo "============================================================"
echo "Нагрузочное тестирование PostgreSQL"
echo "============================================================"
echo "Цель:     $HOST:$PORT / база $DB"
echo "Масштаб:  $SCALE (таблиц = $SCALE * 100000 строк)"
echo "Клиенты:  $CLIENTS"
echo "Транзакции: $TRANSACTIONS на клиента"
echo "============================================================"

# Инициализация тестовых данных
echo ""
echo "[1/3] Инициализация тестовых данных (pgbench)..."
docker exec -e PGPASSWORD="$PASS" postgres-primary \
    pgbench -h "$HOST" -p "$PORT" -U "$USER" -i -s "$SCALE" "$DB" 2>/dev/null || {
    echo "pgbench не найден в контейнере, устанавливаем..."
    docker exec postgres-primary apt-get update >/dev/null 2>&1
    docker exec postgres-primary apt-get install -y --no-install-recommends postgresql-contrib >/dev/null 2>&1
    docker exec -e PGPASSWORD="$PASS" postgres-primary \
        pgbench -h "$HOST" -p "$PORT" -U "$USER" -i -s "$SCALE" "$DB"
}

# Запуск нагрузки
echo ""
echo "[2/3] Запуск нагрузки..."
docker exec -e PGPASSWORD="$PASS" postgres-primary \
    pgbench -h "$HOST" -p "$PORT" -U "$USER" -c "$CLIENTS" -j "$CLIENTS" -t "$TRANSACTIONS" "$DB"

# Проверка репликации после нагрузки
echo ""
echo "[3/3] Проверка лага репликации после нагрузки..."
LAG=$(docker exec -e PGPASSWORD="$PASS" postgres-primary \
    psql -h "$HOST" -p "$PORT" -U "$USER" -Atc "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;" 2>/dev/null || echo "N/A")

if [ "$LAG" != "N/A" ] && [ -n "$LAG" ]; then
    echo "Лаг репликации: $LAG bytes"
    if [ "$LAG" -lt 1024 ]; then
        echo "✓ Репликация синхронна (lag < 1KB)"
    elif [ "$LAG" -lt 1048576 ]; then
        echo "✓ Лаг репликации приемлемый (< 1MB)"
    else
        echo "⚠ Лаг репликации большой (> 1MB)"
    fi
else
    echo "⚠ Не удалось получить статус репликации"
fi

echo "============================================================"
echo "Нагрузочное тестирование завершено"
echo "============================================================"
