#!/bin/bash
set -e

# =============================================================================
# Entrypoint для 1С:Предприятие 8.3 Server (Community Edition)
# =============================================================================

SRV1CV8_PORT=${SRV1CV8_PORT:-1540}
SRV1CV8_REGPORT=${SRV1CV8_REGPORT:-1541}
SRV1CV8_RANGE=${SRV1CV8_RANGE:-1560:1591}
SRV1CV8_DATA=${SRV1CV8_DATA:-/var/lib/1c}
SRV1CV8_DEBUG=${SRV1CV8_DEBUG:-false}

# Поиск установленной версии 1С
V8_DIR=$(find /opt/1cv8/x86_64 -maxdepth 1 -type d | sort -V | tail -n 1)

if [ -z "$V8_DIR" ] || [ ! -d "$V8_DIR" ]; then
    echo "============================================================"
    echo "ОШИБКА: 1С:Предприятие не установлено!"
    echo "Возможные причины:"
    echo "  1. В ZIP-архиве не найден .run установщик"
    echo "  2. Установщик не поддерживает silent-режим"
    echo ""
    echo "Решение: распакуйте .run вручную на Linux-машине:"
    echo "  ./setup-full-*.run --noexec --target ./extracted"
    echo "  затем скопируйте *.deb в docker/1c-server/dist/"
    echo "============================================================"
    exit 1
fi

RAGENT="$V8_DIR/ragent"

if [ ! -x "$RAGENT" ]; then
    echo "ОШИБКА: Не найден исполняемый файл ragent в $V8_DIR"
    exit 1
fi

echo "============================================================"
echo "1С:Предприятие 8.3 Server (Community Edition)"
echo "Версия: $(basename $V8_DIR)"
echo "Данные: $SRV1CV8_DATA"
echo "Порты: $SRV1CV8_PORT / $SRV1CV8_REGPORT / $SRV1CV8_RANGE"
echo "============================================================"

mkdir -p "$SRV1CV8_DATA" "/var/log/1c"
rm -f "$SRV1CV8_DATA"/*.pid 2>/dev/null || true

RAGENT_ARGS=(
    -d "$SRV1CV8_DATA"
    -port "$SRV1CV8_PORT"
    -regport "$SRV1CV8_REGPORT"
    -range "$SRV1CV8_RANGE"
    -seclev "0"
    -pingPeriod "1000"
    -pingTimeout "5000"
)

[ "$SRV1CV8_DEBUG" = "true" ] && RAGENT_ARGS+=("-debug")

echo "Запуск ragent..."
exec "$RAGENT" "${RAGENT_ARGS[@]}"
