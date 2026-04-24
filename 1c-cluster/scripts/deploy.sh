#!/bin/bash

# Скрипт быстрого запуска стенда
set -e

echo "🚀 Запуск отказоустойчивого кластера PostgreSQL для 1С..."

cd "$(dirname "$0")/../docker-compose"

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не найден. Пожалуйста, установите Docker."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose не найден. Пожалуйста, установите Docker Compose."
    exit 1
fi

# Остановка старых контейнеров (если есть)
echo "🧹 Очистка старых контейнеров..."
docker compose down --remove-orphans 2>/dev/null || true

# Запуск сервисов
echo "📦 Запуск сервисов (PostgreSQL Primary, Replica, PgPool, Monitoring)..."
docker compose up -d

echo ""
echo "✅ Стенд запущен!"
echo ""
echo "📊 Полезная информация:"
echo "   - Порт доступа к БД для 1С: localhost:5433 (PgPool)"
echo "   - Логин/Пароль БД: postgres / postgres123"
echo "   - Имя БД: demo_db"
echo ""
echo "📈 Мониторинг:"
echo "   - Grafana: http://localhost:3000 (admin/admin)"
echo "   - Prometheus: http://localhost:9090"
echo "   - HAProxy Stats: http://localhost:8787/stats"
echo ""
echo "🔧 Следующие шаги:"
echo "   1. Убедитесь, что сервер 1С запущен на хосте."
echo "   2. Создайте базу в консоли администрирования 1С:"
echo "      - Сервер БД: localhost"
echo "      - Порт: 5433"
echo "      - Тип СУБД: PostgreSQL"
echo ""
echo "🛑 Для остановки выполните: docker compose down"
