#!/bin/bash
# =============================================================================
# Полный статус кластера 1С + PostgreSQL
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================================"
echo -e "${BLUE}Статус кластера 1С:Предприятие + PostgreSQL${NC}"
echo "============================================================"

# --- Контейнеры ---
echo ""
echo -e "${BLUE}Контейнеры:${NC}"
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"

# --- PostgreSQL ---
echo ""
echo -e "${BLUE}PostgreSQL:${NC}"
for svc in postgres-primary postgres-replica; do
    if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
        ROLE=$(docker exec "$svc" psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "?")
        if [ "$ROLE" = "f" ]; then
            echo -e "  ${GREEN}●${NC} $svc — Primary (запись)"
        elif [ "$ROLE" = "t" ]; then
            echo -e "  ${GREEN}●${NC} $svc — Replica (standby)"
        else
            echo -e "  ${YELLOW}●${NC} $svc — роль не определена"
        fi
    else
        echo -e "  ${RED}●${NC} $svc — не запущен"
    fi
done

# --- Репликация ---
echo ""
echo -e "${BLUE}Репликация:${NC}"
LAG=$(docker exec postgres-primary psql -U postgres -Atc "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;" 2>/dev/null || echo "N/A")
if [ "$LAG" != "N/A" ] && [ -n "$LAG" ]; then
    LAG_MB=$(awk "BEGIN {printf \"%.2f\", $LAG/1024/1024}")
    echo -e "  ${GREEN}●${NC} Лаг репликации: ${LAG_MB} MB"
else
    echo -e "  ${RED}●${NC} Репликация не активна"
fi

# --- 1C Серверы ---
echo ""
echo -e "${BLUE}1С:Предприятие:${NC}"
for srv in 1c-server-1 1c-server-2; do
    if docker ps --format '{{.Names}}' | grep -q "^${srv}$"; then
        if docker exec "$srv" ps aux | grep -v grep | grep -q ragent; then
            echo -e "  ${GREEN}●${NC} $srv — ragent запущен"
        else
            echo -e "  ${RED}●${NC} $srv — ragent НЕ запущен"
        fi
    else
        echo -e "  ${RED}●${NC} $srv — не запущен"
    fi
done

# --- HAProxy ---
echo ""
echo -e "${BLUE}HAProxy (http://localhost:8404/stats):${NC}"
if curl -sf http://admin:admin@localhost:8404/stats >/dev/null 2>&1; then
    UP=$(curl -sf http://admin:admin@localhost:8404/stats 2>/dev/null | grep -o '"status":"[^"]*"' | grep -c 'UP' || echo "0")
    echo -e "  ${GREEN}●${NC} HAProxy доступен, UP серверов: $UP"
else
    echo -e "  ${RED}●${NC} HAProxy недоступен"
fi

# --- Мониторинг ---
echo ""
echo -e "${BLUE}Мониторинг:${NC}"
for svc in prometheus grafana alertmanager; do
    PORT=""
    case "$svc" in
        prometheus)   PORT=9090 ;;
        grafana)      PORT=3000 ;;
        alertmanager) PORT=9093 ;;
    esac
    if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
        echo -e "  ${GREEN}●${NC} $svc — http://localhost:$PORT"
    else
        echo -e "  ${RED}●${NC} $svc — не запущен"
    fi
done

# --- Диск ---
echo ""
echo -e "${BLUE}Ресурсы хоста:${NC}"
df -h / | tail -1 | awk '{print "  Диск: использовано " $3 " / " $2 " (" $5 ")"}'
free -h | awk '/^Mem:/{print "  RAM:  использовано " $3 " / " $2}'

echo "============================================================"
