#!/bin/bash
# Скрипт быстрого развёртывания кластера 1С

set -e

echo "🚀 Развёртывание отказоустойчивого кластера 1С..."

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не найден. Пожалуйста, установите Docker."
    exit 1
fi

# Проверка наличия Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose не найден. Пожалуйста, установите Docker Compose."
    exit 1
fi

echo "✅ Docker и Docker Compose найдены"

# Переход в директорию с docker-compose
cd "$(dirname "$0")/docker-compose"

echo "📦 Запуск контейнеров..."
docker compose up -d

echo ""
echo "⏳ Ожидание готовности сервисов (30 секунд)..."
sleep 30

echo ""
echo "📊 Статус контейнеров:"
docker compose ps

echo ""
echo "✅ Кластер успешно развёрнут!"
echo ""
echo "🔌 Доступные сервисы:"
echo "   • PostgreSQL (через PgPool): localhost:5433"
echo "   • 1С RAS (балансировщик): localhost:1541"
echo "   • Веб-сервисы 1С: localhost:8080"
echo "   • Prometheus: http://localhost:9090"
echo "   • Grafana: http://localhost:3000 (admin/admin123)"
echo "   • HAProxy Stats: http://localhost:8404/stats"
echo ""
echo "📝 Для остановки выполните: docker compose down"
