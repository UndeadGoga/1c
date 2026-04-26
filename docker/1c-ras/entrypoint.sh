#!/bin/bash
set -e

# =============================================================================
# Entrypoint для RAS (Remote Administration Server)
# =============================================================================

RAS_CLUSTER_HOST=${RAS_CLUSTER_HOST:-1c-server-1}
RAS_PORT=${RAS_PORT:-1545}
CLUSTER_PORT=${CLUSTER_PORT:-1540}

V8_DIR=$(find /opt/1cv8/x86_64 -maxdepth 1 -type d | sort -V | tail -n 1)
RAS_BIN="$V8_DIR/ras"

if [ ! -x "$RAS_BIN" ]; then
    echo "============================================================"
    echo "ОШИБКА: RAS не найден!"
    echo "============================================================"
    exit 1
fi

echo "============================================================"
echo "Запуск RAS (Remote Administration Server)"
echo "Кластер: $RAS_CLUSTER_HOST:$CLUSTER_PORT"
echo "Порт RAS: $RAS_PORT"
echo "============================================================"

exec "$RAS_BIN" "cluster" "$RAS_CLUSTER_HOST:$CLUSTER_PORT" "--port=$RAS_PORT"
