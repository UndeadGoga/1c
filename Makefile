# =============================================================================
# Makefile для управления отказоустойчивым кластером 1С
# =============================================================================

.PHONY: help check build up down logs ps test status failover clean load-test

help:
	@echo "Доступные команды:"
	@echo "  make check       - проверка окружения и дистрибутивов"
	@echo "  make build       - сборка всех Docker-образов"
	@echo "  make up          - запуск всей инфраструктуры"
	@echo "  make down        - остановка всей инфраструктуры"
	@echo "  make ps          - статус контейнеров"
	@echo "  make logs        - просмотр логов"
	@echo "  make test        - проверка здоровья кластера"
	@echo "  make load-test   - нагрузочное тестирование PostgreSQL (pgbench)"
	@echo "  make pg-failover - тест failover PostgreSQL"
	@echo "  make ha-failover - тест отказоустойчивости HAProxy"
	@echo "  make status      - полный отчёт о состоянии"
	@echo "  make clean       - удаление контейнеров и volumes"

check:
	@bash scripts/build-and-test.sh

build:
	@echo "=== Сборка всех образов ==="
	@docker compose build

up:
	@docker compose up -d

down:
	@docker compose down

ps:
	@docker compose ps

logs:
	@docker compose logs -f --tail=50

test:
	@bash scripts/health-check.sh

load-test:
	@bash scripts/load-test-pg.sh

pg-failover:
	@bash scripts/test-failover.sh

ha-failover:
	@bash scripts/test-haproxy-failover.sh

status:
	@bash scripts/status.sh

clean:
	@docker compose down -v --remove-orphans
	@echo "Контейнеры и volumes удалены. Образы сохранены."
