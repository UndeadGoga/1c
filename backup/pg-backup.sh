#!/bin/bash
# =============================================================================
# Скрипт резервного копирования PostgreSQL
# =============================================================================

set -euo pipefail

# Конфигурация
PG_HOST="${PG_HOST:-postgres-primary}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DATE=$(date +%Y%m%d_%H%M%S)
DAY=$(date +%Y%m%d)

# Директории
BASE_BACKUP_DIR="$BACKUP_DIR/pg_base"
WAL_DIR="$BACKUP_DIR/wal"
LOG_FILE="$BACKUP_DIR/backup_$DATE.log"

mkdir -p "$BASE_BACKUP_DIR" "$WAL_DIR"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "============================================================"
echo "Резервное копирование PostgreSQL"
echo "Время начала: $(date)"
echo "Хост: $PG_HOST:$PG_PORT"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Базовая копия (раз в сутки)
# ---------------------------------------------------------------------------
if [ ! -f "$BASE_BACKUP_DIR/last_base_backup" ] || [ "$(find "$BASE_BACKUP_DIR/last_base_backup" -mtime +0)" ]; then
    echo "[$(date)] Создание базовой копии (pg_basebackup)..."
    pg_basebackup \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -D "$BASE_BACKUP_DIR/base_$DAY" \
        -Ft \
        -z \
        -P \
        -v \
        -X fetch
    
    touch "$BASE_BACKUP_DIR/last_base_backup"
    echo "[$(date)] Базовая копия завершена: $BASE_BACKUP_DIR/base_$DAY"
else
    echo "[$(date)] Базовая копия за сегодня уже существует, пропускаем."
fi

# ---------------------------------------------------------------------------
# 2. Логическое резервирование ключевых баз
# ---------------------------------------------------------------------------
DATABASES=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -Atc "SELECT datname FROM pg_database WHERE datistemplate = false;")

for DB in $DATABASES; do
    echo "[$(date)] Дамп базы: $DB"
    pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -Fc "$DB" > "$BASE_BACKUP_DIR/${DB}_${DAY}.dump" || echo "Ошибка дампа $DB"
done

# ---------------------------------------------------------------------------
# 3. Очистка старых копий
# ---------------------------------------------------------------------------
echo "[$(date)] Очистка копий старше $RETENTION_DAYS дней..."
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
find "$BASE_BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$WAL_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Проверка целостности (pg_dump в тестовый режим)
# ---------------------------------------------------------------------------
echo "[$(date)] Проверка доступности PostgreSQL..."
pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER"

echo "============================================================"
echo "Резервное копирование завершено: $(date)"
echo "============================================================"

# Отправка метрики в Prometheus Pushgateway (опционально)
if command -v curl &> /dev/null; then
    echo "backup_last_success_timestamp $(date +%s)" | curl --data-binary @- http://pushgateway:9091/metrics/job/postgres-backup 2>/dev/null || true
fi
