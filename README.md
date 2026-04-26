# Отказоустойчивый кластер 1С:Предприятие 8.3 (Community Edition)

Дипломный проект: **Исследование и разработка архитектуры отказоустойчивого кластера 1С:Предприятие**

> **Важно:** проект использует только бесплатное и свободное ПО.
> - 1С:Предприятие 8.3 Community Edition — бесплатная лицензия для обучения и разработки
> - PostgreSQL 16 (официальный образ) — Open Source
> - Остальные компоненты — Open Source

## Состав решения

| Компонент | Технология | Лицензия | Назначение |
|-----------|-----------|----------|------------|
| 1С:Предприятие | 8.3.27 Community Edition | Бесплатно (для обучения/разработки) | Прикладные серверы |
| PostgreSQL | 16 (официальный Docker-образ) | PostgreSQL License (Open Source) | Хранилище данных |
| Балансировка | HAProxy | GPL v2 | TCP-балансировка |
| Мониторинг | Prometheus + Grafana + Alertmanager | Apache 2.0 | Метрики, дашборды, алерты |
| Автоматизация | Terraform + Ansible | MPL / GPL | IaC и настройка ОС |
| Резервное копирование | shell-скрипты + pg_basebackup | — | Backup БД и ИБ |
| Failover | shell-скрипты | — | Ручное/скриптовое переключение |

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                        Пользователи                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                     HAProxy (VIP)                            │
│              TCP-балансировка портов 1С (1540/1541/1545)    │
└───────────────┬───────────────────────┬─────────────────────┘
                │                       │
    ┌───────────▼──────────┐  ┌────────▼────────┐
    │  1С:Сервер #1        │  │  1С:Сервер #2   │
    │  (Community Edition) │  │  (Community)    │
    │   ragent, rmngr,     │  │   ragent, rmngr,│
    │   rphost)            │  │   rphost)       │
    └───────────┬──────────┘  └────────┬────────┘
                │                      │
    ┌───────────▼──────────────────────▼────────┐
    │      PostgreSQL 16 Primary (Master)       │
    │         ↕ Потоковая репликация            │
    │      PostgreSQL 16 Replica (Standby)      │
    └───────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Prometheus ← node-exporter / postgres-exporter / blackbox  │
│  Grafana → Визуализация дашбордов                           │
│  Alertmanager → Email оповещения                            │
│  cadvisor → Метрики Docker-контейнеров                      │
└─────────────────────────────────────────────────────────────┘
```

## Быстрый старт

### 1. Требования

- Docker Engine 24.0+ + Docker Compose plugin (v2)
- Дистрибутив 1С:Предприятие 8.3 Community Edition (`server64_*.zip`)
- Ubuntu 22.04 (для интерактивной установки 1С на хост)
- 4 GB RAM минимум, 8 GB рекомендуется

### 2. Подготовка 1С (обязательный шаг)

Установщик 1С интерактивный и не поддерживает silent-установку в Docker.
Установите 1С на хост, затем скопируйте файлы:

```bash
# Распакуйте server64_*.zip и запустите установщик на Ubuntu-сервере
sudo ./setup-full-8.3.27.1936-x86_64.run
# Выберите русский язык (17), согласитесь с лицензией, дождитесь окончания

# Скопируйте установленные файлы в проект
bash scripts/prepare-1c-dist.sh
# Или вручную: sudo cp -r /opt/1cv8 docker/1c-server/dist/opt-1cv8
```

### 3. Развёртывание через Docker Compose

```bash
# Единый запуск всей инфраструктуры
make up
# или: docker compose up -d

# Проверка здоровья
make test
# или: bash scripts/health-check.sh

# Полный статус
make status
```

### 4. Нагрузочное тестирование и отказоустойчивость

```bash
# Нагрузка PostgreSQL (pgbench)
make load-test

# Тест failover PostgreSQL
make pg-failover

# Тест отказоустойчивости HAProxy
make ha-failover
```

### 5. Доступ к сервисам

| Сервис | URL | Логин / Пароль |
|--------|-----|----------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |
| HAProxy Stats | http://localhost:8404/stats | admin / admin |
| PostgreSQL Primary | localhost:5432 | postgres / postgres_password |
| PostgreSQL Replica | localhost:5433 | postgres / postgres_password |

## Документация

- [Архитектурное описание](docs/architecture.md)
- [Сценарии Disaster Recovery](docs/disaster-recovery.md)
- [Руководство по развёртыванию](docs/setup-guide.md)

## Структура проекта

```
.
├── docker-compose.yml          # Корневой compose (include: postgres, docker, monitoring)
├── Makefile                    # Команды: make up / down / test / load-test / ...
├── docker/
│   ├── docker-compose.yml      # 1С-серверы, HAProxy, RAS
│   ├── 1c-server/              # Dockerfile + entrypoint для сервера 1С
│   ├── 1c-ras/                 # Dockerfile + entrypoint для RAS
│   └── haproxy/
│       └── haproxy.cfg         # TCP-балансировка 1540/1541/1545
├── postgres/
│   ├── docker-compose.yml      # PostgreSQL Primary + Replica
│   ├── primary/                # Dockerfile, init-скрипты, конфиги
│   └── replica/                # Dockerfile, init-скрипты, конфиги
├── monitoring/
│   ├── docker-compose.yml      # Prometheus, Grafana, Alertmanager, exporters
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
├── scripts/
│   ├── health-check.sh         # Проверка здоровья кластера
│   ├── load-test-pg.sh         # Нагрузка PostgreSQL (pgbench)
│   ├── test-failover.sh        # Тест failover PostgreSQL
│   ├── test-haproxy-failover.sh # Тест HAProxy
│   ├── start-all.sh
│   ├── stop-all.sh
│   └── failover.sh
├── ansible/                    # Автоматизация настройки ОС
├── terraform/                  # IaC (Yandex Cloud / etc.)
└── docs/                       # Документация и диаграммы
```

## Ограничения Community Edition

- До 5 одновременных сеансов
- Только для обучения, разработки и тестирования
- Для production требуется приобретение лицензии 1С:Предприятие

## Лицензии

- 1С:Предприятие Community Edition — проприетарная, бесплатная для обучения
- PostgreSQL — PostgreSQL License (Open Source)
- HAProxy — GPL v2
- Prometheus / Grafana / Alertmanager — Apache 2.0
- Terraform — MPL 2.0 / BUSL
- Ansible — GPL v3
