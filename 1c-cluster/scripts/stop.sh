#!/bin/bash
# Скрипт остановки кластера 1С

set -e

echo "🛑 Остановка отказоустойчивого кластера 1С..."

cd "$(dirname "$0")/docker-compose"

echo "📦 Остановка контейнеров..."
docker compose down

echo ""
echo "✅ Кластер успешно остановлен!"
echo ""
echo "📝 Для запуска выполните: ./scripts/deploy.sh"
