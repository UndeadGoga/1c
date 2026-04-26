#!/bin/bash
# =============================================================================
# Скрипт сборки и тестирования на Ubuntu
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

echo "============================================================"
echo "Проверка окружения перед сборкой"
echo "============================================================"

# --- Docker ---
if command -v docker &>/dev/null; then
    log_ok "Docker установлен: $(docker --version)"
else
    log_fail "Docker НЕ установлен! Установите: sudo apt install docker.io docker-compose-plugin"
    exit 1
fi

if docker compose version &>/dev/null; then
    log_ok "Docker Compose plugin установлен: $(docker compose version)"
else
    log_fail "Docker Compose plugin НЕ установлен!"
    exit 1
fi

# --- RAM ---
RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
if [ "$RAM_MB" -gt 4000 ]; then
    log_ok "RAM: ${RAM_MB}MB (достаточно)"
else
    log_warn "RAM: ${RAM_MB}MB (рекомендуется минимум 4GB)"
fi

# --- Диск ---
DISK_GB=$(df -BG "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "${DISK_GB:-0}" -gt 30 ]; then
    log_ok "Свободно на диске: ${DISK_GB}GB"
else
    log_warn "Свободно на диске: ${DISK_GB}GB (рекомендуется минимум 30GB)"
fi

# --- Дистрибутивы ---
if [ -d "$PROJECT_DIR/docker/1c-server/dist/opt-1cv8" ] && [ "$(ls -A "$PROJECT_DIR/docker/1c-server/dist/opt-1cv8" 2>/dev/null)" ]; then
    log_ok "Дистрибутив 1С найден (dist/opt-1cv8)"
else
    log_warn "Дистрибутив 1С НЕ найден! Скопируйте /opt/1cv8 в docker/1c-server/dist/opt-1cv8"
fi

echo ""
echo "============================================================"
echo "Сборка всех образов"
echo "============================================================"
cd "$PROJECT_DIR"
docker compose build

echo ""
echo "============================================================"
echo "Запуск инфраструктуры"
echo "============================================================"
docker compose up -d
sleep 10

echo ""
echo "============================================================"
echo "Проверка здоровья"
echo "============================================================"
bash "$PROJECT_DIR/scripts/health-check.sh"

echo ""
echo "============================================================"
echo "Итог проверки"
echo "============================================================"
log_ok "Инфраструктура собрана и запущена"
echo ""
echo "Полезные команды:"
echo "  make test         — проверка здоровья"
echo "  make load-test    — нагрузка PostgreSQL (pgbench)"
echo "  make pg-failover  — тест failover PostgreSQL"
echo "  make ha-failover  — тест отказоустойчивости HAProxy"
echo "============================================================"
