#!/bin/bash
# =============================================================================
# Тест отказоустойчивости HAProxy (отказ одного из серверов 1С)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

check_haproxy() {
    curl -sf http://admin:admin@localhost:8404/stats;format=json 2>/dev/null | \
        grep -o '"status":"[^"]*"' | grep -c 'UP' || echo "0"
}

echo "============================================================"
echo "Тест отказоустойчивости HAProxy"
echo "============================================================"

# --- Шаг 1: Проверяем исходное состояние ---
echo ""
echo "[1/4] Проверка исходного состояния HAProxy..."
UP_COUNT=$(check_haproxy)
if [ "$UP_COUNT" -ge 4 ]; then
    log_ok "HAProxy: $UP_COUNT сервера UP (1c-srv1, 1c-srv2, ras)"
else
    log_warn "HAProxy: только $UP_COUNT серверов UP (ожидалось 4+)"
fi

# --- Шаг 2: Останавливаем 1c-server-1 ---
echo ""
echo "[2/4] Имитация отказа 1c-server-1..."
docker stop 1c-server-1 >/dev/null 2>&1
log_ok "1c-server-1 остановлен"

echo "Ожидание 5 секунд (health check interval)..."
sleep 5

# --- Шаг 3: Проверяем переключение ---
echo ""
echo "[3/4] Проверка переключения HAProxy..."
UP_COUNT=$(check_haproxy)

# Проверяем статус через API HAProxy
if curl -sf http://admin:admin@localhost:8404/stats 2>/dev/null | grep -q "1c-server-1.*DOWN"; then
    log_ok "1c-server-1 помечен как DOWN в HAProxy"
else
    log_warn "1c-server-1 ещё не помечен как DOWN (возможно, нужно больше времени)"
fi

if curl -sf http://admin:admin@localhost:8404/stats 2>/dev/null | grep -q "1c-server-2.*UP"; then
    log_ok "1c-server-2 остаётся UP"
fi

# Проверяем, что порты HAProxy всё ещё слушаются
if nc -z localhost 1540 2>/dev/null; then
    log_ok "Порт 1540 (ragent) доступен через HAProxy"
else
    log_fail "Порт 1540 НЕ доступен!"
fi

if nc -z localhost 1541 2>/dev/null; then
    log_ok "Порт 1541 (rmngr) доступен через HAProxy"
else
    log_fail "Порт 1541 НЕ доступен!"
fi

# --- Шаг 4: Восстанавливаем 1c-server-1 ---
echo ""
echo "[4/4] Восстановление 1c-server-1..."
docker start 1c-server-1 >/dev/null 2>&1
sleep 5

if docker exec 1c-server-1 ps aux | grep -v grep | grep -q ragent; then
    log_ok "1c-server-1 восстановлен, ragent запущен"
else
    log_warn "1c-server-1 запущен, но ragent ещё не поднялся"
fi

echo "============================================================"
echo "Тест HAProxy failover завершён"
echo "============================================================"
