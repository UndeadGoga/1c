#!/bin/bash
# =============================================================================
# Скрипт проверки здоровья кластера 1С + PostgreSQL
# =============================================================================

set -uo pipefail

EXIT_CODE=0

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; EXIT_CODE=1; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; EXIT_CODE=1; }

# =============================================================================
# Проверка PostgreSQL Primary
# =============================================================================
check_postgres_primary() {
    echo "=== PostgreSQL Primary ==="
    if docker exec postgres-primary pg_isready -U postgres >/dev/null 2>&1; then
        log_ok "PostgreSQL Primary отвечает"
        
        local recovery
        recovery=$(docker exec postgres-primary psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null)
        if [ "$recovery" = "f" ]; then
            log_ok "PostgreSQL Primary в режиме записи"
        else
            log_fail "PostgreSQL Primary в режиме recovery (неожиданно)"
        fi
        
        local conn_count
        conn_count=$(docker exec postgres-primary psql -U postgres -Atc "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null)
        log_ok "Активных подключений: $conn_count"
    else
        log_fail "PostgreSQL Primary НЕ отвечает"
    fi
}

# =============================================================================
# Проверка PostgreSQL Replica
# =============================================================================
check_postgres_replica() {
    echo "=== PostgreSQL Replica ==="
    if docker exec postgres-replica pg_isready -U postgres >/dev/null 2>&1; then
        log_ok "PostgreSQL Replica отвечает"
        
        local recovery
        recovery=$(docker exec postgres-replica psql -U postgres -Atc "SELECT pg_is_in_recovery();" 2>/dev/null)
        if [ "$recovery" = "t" ]; then
            log_ok "PostgreSQL Replica в режиме standby"
        else
            log_warn "PostgreSQL Replica НЕ в режиме standby (возможно, был failover)"
        fi
    else
        log_fail "PostgreSQL Replica НЕ отвечает"
    fi
}

# =============================================================================
# Проверка репликации
# =============================================================================
check_replication() {
    echo "=== Репликация ==="
    local lag
    lag=$(docker exec postgres-primary psql -U postgres -Atc "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;" 2>/dev/null)
    
    if [ -n "$lag" ] && [ "$lag" != "" ]; then
        log_ok "Задержка репликации: $lag bytes"
        if [ "$lag" -gt 104857600 ]; then
            log_warn "Задержка репликации > 100 MB"
        fi
    else
        log_fail "Репликация не работает или нет активных standby"
    fi
}

# =============================================================================
# Проверка 1С серверов
# =============================================================================
check_1c_servers() {
    echo "=== 1С:Предприятие Серверы ==="
    for srv in 1c-server-1 1c-server-2; do
        if docker exec "$srv" ps aux | grep -v grep | grep ragent >/dev/null 2>&1; then
            log_ok "$srv: ragent запущен"
        else
            log_fail "$srv: ragent НЕ запущен"
        fi
        
        if docker exec "$srv" ps aux | grep -v grep | grep rmngr >/dev/null 2>&1; then
            log_ok "$srv: rmngr запущен"
        else
            log_warn "$srv: rmngr НЕ запущен"
        fi
        
        if docker exec "$srv" ps aux | grep -v grep | grep rphost >/dev/null 2>&1; then
            log_ok "$srv: rphost запущен"
        else
            log_warn "$srv: rphost НЕ запущен"
        fi
    done
}

# =============================================================================
# Проверка HAProxy
# =============================================================================
check_haproxy() {
    echo "=== HAProxy ==="
    if curl -sf http://admin:admin@localhost:8404/stats >/dev/null 2>&1; then
        log_ok "HAProxy статистика доступна"
    else
        log_warn "HAProxy статистика НЕ доступна (порт 8404)"
    fi
}

# =============================================================================
# Проверка мониторинга
# =============================================================================
check_monitoring() {
    echo "=== Мониторинг ==="
    if curl -sf http://localhost:9090/-/healthy >/dev/null 2>&1; then
        log_ok "Prometheus доступен"
    else
        log_warn "Prometheus НЕ доступен"
    fi
    
    if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then
        log_ok "Grafana доступна"
    else
        log_warn "Grafana НЕ доступна"
    fi
}

# =============================================================================
# Проверка бэкапов
# =============================================================================
check_backups() {
    echo "=== Резервное копирование ==="
    local last_backup
    last_backup=$(find /backup -type f -name "*.dump" -o -name "*.dt" 2>/dev/null | sort -r | head -n 1)
    
    if [ -n "$last_backup" ]; then
        local age
        age=$(( ( $(date +%s) - $(stat -c %Y "$last_backup" 2>/dev/null || stat -f %m "$last_backup") ) / 3600 ))
        if [ "$age" -lt 25 ]; then
            log_ok "Последний backup: $last_backup (${age}ч назад)"
        else
            log_warn "Последний backup старше 24 часов: $last_backup"
        fi
    else
        log_warn "Backup-файлы не найдены"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "============================================================"
    echo "Проверка здоровья кластера 1С: $(date)"
    echo "============================================================"
    
    check_postgres_primary
    check_postgres_replica
    check_replication
    check_1c_servers
    check_haproxy
    check_monitoring
    check_backups
    
    echo "============================================================"
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}Кластер работает нормально.${NC}"
    else
        echo -e "${YELLOW}Обнаружены проблемы, требующие внимания.${NC}"
    fi
    echo "============================================================"
    
    exit $EXIT_CODE
}

main "$@"
