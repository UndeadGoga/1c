#!/bin/bash
# =============================================================================
# Скрипт ручного failover PostgreSQL в Docker-инфраструктуре
# =============================================================================
set -euo pipefail

PRIMARY="postgres-primary"
REPLICA="postgres-replica"

echo "============================================================"
echo "Failover PostgreSQL (Docker)"
echo "============================================================"

# Проверяем состояние
echo ""
echo "Текущее состояние:"
for svc in $PRIMARY $REPLICA; do
    if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
        ROLE=$(docker exec "$svc" psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "?")
        if [ "$ROLE" = "f" ]; then
            echo "  $svc — Primary"
        elif [ "$ROLE" = "t" ]; then
            echo "  $svc — Replica"
        else
            echo "  $svc — неизвестно"
        fi
    else
        echo "  $svc — остановлен"
    fi
done

echo ""
read -p "Выполнить promote $REPLICA в Primary? [y/N] " ans
if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
    echo "Отмена."
    exit 0
fi

# Promote
echo ""
echo "Остановка $PRIMARY..."
docker stop "$PRIMARY" >/dev/null 2>&1 || true

echo "Promote $REPLICA..."
docker exec "$REPLICA" pg_ctl promote -D /var/lib/postgresql/data

sleep 3

ROLE=$(docker exec "$REPLICA" psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "?")
if [ "$ROLE" = "f" ]; then
    echo "✓ $REPLICA теперь Primary (принимает запись)"
else
    echo "✗ Promote не удался (role=$ROLE)"
    exit 1
fi

echo ""
echo "============================================================"
echo "Failover выполнен."
echo "Новый Primary: $REPLICA"
echo ""
echo "Для восстановления топологии выполните:"
echo "  sudo docker compose down -v"
echo "  sudo docker compose up -d"
echo "============================================================"
