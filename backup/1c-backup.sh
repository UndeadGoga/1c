#!/bin/bash
# =============================================================================
# Скрипт резервного копирования информационных баз 1С
# =============================================================================

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backup/1c}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DATE=$(date +%Y%m%d_%H%M%S)
DAY=$(date +%Y%m%d)
LOG_FILE="$BACKUP_DIR/backup_$DATE.log"

mkdir -p "$BACKUP_DIR"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "============================================================"
echo "Резервное копирование информационных баз 1С"
echo "Время начала: $(date)"
echo "============================================================"

# Проверка наличия rac
RAC=$(find /opt/1cv8/x86_64 -name rac | sort -V | tail -n 1)
if [ -z "$RAC" ] || [ ! -x "$RAC" ]; then
    echo "ОШИБКА: Утилита rac не найдена!"
    exit 1
fi

# Получение списка информационных баз
CLUSTERS=$($RAC cluster list localhost:1545 2>/dev/null | grep "cluster" | awk '{print $3}' || true)

for CLUSTER in $CLUSTERS; do
    echo "[$(date)] Обработка кластера: $CLUSTER"
    
    INFOBASES=$($RAC infobase --cluster="$CLUSTER" summary list localhost:1545 2>/dev/null | grep "infobase" | awk '{print $3}' || true)
    
    for IB in $INFOBASES; do
        IB_NAME=$($RAC infobase --cluster="$CLUSTER" info --infobase="$IB" localhost:1545 2>/dev/null | grep "name:" | head -n 1 | cut -d':' -f2 | xargs || echo "$IB")
        echo "[$(date)] Выгрузка ИБ: $IB_NAME ($IB)"
        
        # Выгрузка через rac (dt-формат)
        $RAC infobase --cluster="$CLUSTER" dump \
            --infobase="$IB" \
            --output="$BACKUP_DIR/${IB_NAME}_${DAY}.dt" \
            localhost:1545 2>/dev/null || echo "Ошибка выгрузки $IB_NAME"
    done
done

# Очистка старых копий
echo "[$(date)] Очистка копий старше $RETENTION_DAYS дней..."
find "$BACKUP_DIR" -name "*.dt" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "backup_*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

echo "============================================================"
echo "Резервное копирование 1С завершено: $(date)"
echo "============================================================"
