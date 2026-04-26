#!/bin/bash
# =============================================================================
# Запуск всей инфраструктуры
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "Запуск отказоустойчивого кластера 1С"
echo "============================================================"

cd "$PROJECT_DIR"

echo "[1/1] Запуск всей инфраструктуры через корневой compose..."
docker compose up -d

echo "============================================================"
echo "Инфраструктура запущена!"
echo ""
echo "Доступные сервисы:"
echo "  Grafana:        http://localhost:3000  (admin / admin)"
echo "  Prometheus:     http://localhost:9090"
echo "  Alertmanager:   http://localhost:9093"
echo "  1С RAS:         localhost:1545"
echo "  HAProxy Stats:  http://localhost:8404/stats  (admin / admin)"
echo ""
echo "  PostgreSQL:     localhost:5432 (primary), localhost:5433 (replica)"
echo "============================================================"
