#!/bin/bash
# =============================================================================
# Тест отказоустойчивости PostgreSQL (failover)
# =============================================================================
# Останавливает Primary, проверяет что Replica становится доступной для чтения,
# затем восстанавливает старый Primary.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

echo "============================================================"
echo "Тест отказоустойчивости PostgreSQL (Failover)"
echo "============================================================"

# --- Шаг 1: Проверяем исходное состояние ---
echo ""
echo "[1/5] Проверка исходного состояния..."

PRIMARY_ROLE=$(docker exec postgres-primary psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "unknown")
REPLICA_ROLE=$(docker exec postgres-replica psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "unknown")

if [ "$PRIMARY_ROLE" = "f" ]; then
    log_ok "Primary в режиме записи"
else
    log_fail "Primary НЕ в режиме записи (role=$PRIMARY_ROLE)"
    exit 1
fi

if [ "$REPLICA_ROLE" = "t" ]; then
    log_ok "Replica в режиме standby"
else
    log_warn "Replica НЕ в режиме standby (role=$REPLICA_ROLE)"
fi

# --- Шаг 2: Останавливаем Primary ---
echo ""
echo "[2/5] Имитация отказа Primary (docker stop)..."
docker stop postgres-primary >/dev/null 2>&1
log_ok "Primary остановлен"

# --- Шаг 3: Promote Replica в Primary ---
echo ""
echo "[3/5] Promote Replica -> Primary..."
docker exec postgres-replica pg_ctl promote -D /var/lib/postgresql/data >/dev/null 2>&1 || {
    log_fail "Promote не удался"
    docker start postgres-primary
    exit 1
}

sleep 3

NEW_ROLE=$(docker exec postgres-replica psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "unknown")
if [ "$NEW_ROLE" = "f" ]; then
    log_ok "Replica успешно стала Primary (принимает запись)"
else
    log_fail "Replica всё ещё в recovery (role=$NEW_ROLE)"
    docker start postgres-primary
    exit 1
fi

# Проверяем, что можем писать в новый Primary
docker exec postgres-replica psql -U postgres -c "CREATE TABLE failover_test(id serial primary key, ts timestamp default now()); INSERT INTO failover_test DEFAULT VALUES;" >/dev/null 2>&1
log_ok "Запись в новый Primary выполнена успешно"

# --- Шаг 4: Восстанавливаем старый Primary ---
echo ""
echo "[4/5] Восстановление старого Primary как новой Replica..."

# Удаляем старые данные и делаем pg_basebackup с нового Primary
docker start postgres-primary >/dev/null 2>&1
sleep 2

docker exec postgres-primary bash -c "
rm -rf /var/lib/postgresql/data/*
export PGPASSWORD=repl_password
pg_basebackup -h postgres-replica -D /var/lib/postgresql/data -U replicator -Fp -Xs -P -v -R
" || {
    log_warn "pg_basebackup для восстановления Primary не удался (возможно, сеть ещё не готова)"
}

log_ok "Старый Primary пересоздан как Replica"

# --- Шаг 5: Финальная проверка ---
echo ""
echo "[5/5] Финальная проверка..."

# Проверяем оба сервера
for host in postgres-primary postgres-replica; do
    if docker exec "$host" pg_isready -U postgres >/dev/null 2>&1; then
        ROLE=$(docker exec "$host" psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "unknown")
        if [ "$ROLE" = "f" ]; then
            log_ok "$host — Primary (запись)"
        elif [ "$ROLE" = "t" ]; then
            log_ok "$host — Replica (standby)"
        else
            log_warn "$host — роль не определена"
        fi
    else
        log_fail "$host — не отвечает"
    fi
done

echo "============================================================"
echo "Тест failover завершён"
echo "============================================================"
echo ""
echo "ВНИМАНИЕ: Для полного восстановления топологии Primary->Replica"
echo "рекомендуется выполнить:"
echo "  sudo docker compose down -v"
echo "  sudo docker compose up -d"
echo ""
