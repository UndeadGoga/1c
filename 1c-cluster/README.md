# Отказоустойчивый кластер 1С:Предприятие с PostgreSQL

Архитектура отказоустойчивого кластера 1С для локального развёртывания с использованием Docker, Prometheus, Grafana, Ansible и Terraform.

## 📋 Компоненты

### Уровень СУБД (PostgreSQL)
- **PostgreSQL Primary** - основной сервер БД
- **PostgreSQL Replica** - реплика для отказоустойчивости
- **PgPool-II** - балансировщик нагрузки и connection pooling

### Уровень 1С
- **RAS Primary** - основной агент кластера 1С
- **RAS Replica** - резервный агент кластера
- **HAProxy** - балансировщик нагрузки для 1С

### Мониторинг
- **Prometheus** - сбор метрик
- **Grafana** - визуализация
- **Node Exporter** - метрики хоста

## 🚀 Быстрый старт

### Вариант 1: Docker Compose (рекомендуется)

```bash
cd docker-compose

# Запуск всего кластера
docker compose up -d

# Проверка статуса
docker compose ps

# Просмотр логов
docker compose logs -f

# Остановка
docker compose down
```

### Вариант 2: Ansible

```bash
cd ansible

# Запуск playbook
ansible-playbook deploy-1c-cluster.yml -i inventory.ini
```

### Вариант 3: Terraform

```bash
cd terraform

# Инициализация
terraform init

# Применение конфигурации
terraform apply

# Удаление
terraform destroy
```

## 🔌 Доступные сервисы

| Сервис | Порт | URL/Access |
|--------|------|------------|
| PostgreSQL (через PgPool) | 5433 | `localhost:5433` |
| 1С RAS (балансировщик) | 1541 | `localhost:1541` |
| Веб-сервисы 1С | 8080 | `http://localhost:8080` |
| Prometheus | 9090 | `http://localhost:9090` |
| Grafana | 3000 | `http://localhost:3000` (admin/admin123) |
| HAProxy Stats | 8404 | `http://localhost:8404/stats` |

## 📁 Структура проекта

```
1c-cluster/
├── docker-compose/
│   ├── docker-compose.yml    # Основная конфигурация
│   └── haproxy.cfg           # Конфигурация HAProxy
├── monitoring/
│   ├── prometheus.yml        # Конфигурация Prometheus
│   └── grafana/
│       ├── datasources/      # Источники данных Grafana
│       └── dashboards/       # Дашборды Grafana
├── scripts/
│   └── init-db.sh            # Скрипт инициализации БД
├── ansible/
│   ├── deploy-1c-cluster.yml # Playbook для развёртывания
│   ├── inventory.ini         # Inventory файл
│   └── ansible.cfg           # Конфигурация Ansible
├── terraform/
│   └── main.tf               # Terraform конфигурация
└── README.md                 # Этот файл
```

## ⚙️ Конфигурация

### Переменные окружения

#### PostgreSQL
- `POSTGRES_USER`: postgres
- `POSTGRES_PASSWORD`: postgres123

#### 1С
- `SRV1CV8_USERS`: usr1cv
- `SRV1CV8_PWD`: passwd123

#### Grafana
- Логин: `admin`
- Пароль: `admin123`

## 🔧 Управление

### Перезапуск отдельных сервисов

```bash
docker compose restart ras-primary
docker compose restart pg-primary
```

### Масштабирование

Для добавления дополнительных серверов 1С отредактируйте `docker-compose.yml` и добавьте новые сервисы по аналогии с `ras-primary` и `ras-replica`.

### Резервное копирование

```bash
# Бэкап PostgreSQL
docker exec pg-primary pg_dumpall -U postgres > backup.sql

# Восстановление
docker exec -i pg-primary psql -U postgres < backup.sql
```

## 📊 Мониторинг

### Prometheus метрики

- Метрики хоста: `node-exporter:9100`
- Метрики PostgreSQL: через postgres-exporter
- Метрики HAProxy: `haproxy-1c:8404/stats`

### Grafana дашборды

В комплект входит базовый дашборд "1C Cluster Overview" с метриками:
- Использование CPU
- Использование памяти
- Статус PostgreSQL
- Статус backend серверов HAProxy

## ⚠️ Важные замечания

1. **Лицензии 1С**: Для работы серверов 1С необходимы действующие лицензии. В демо-режиме используйте ключи защиты или программные лицензии.

2. **Производительность**: Данная конфигурация предназначена для тестирования и разработки. Для production среды рекомендуется:
   - Выделить отдельные физические/виртуальные машины
   - Настроить SSD хранилища
   - Увеличить ресурсы (CPU, RAM)
   - Настроить сетевую инфраструктуру

3. **Безопасность**: 
   - Измените пароли по умолчанию перед использованием в production
   - Настройте firewall правила
   - Используйте SSL/TLS для внешних подключений

4. **Отказоустойчивость**: 
   - Репликация PostgreSQL настроена в режиме streaming
   - HAProxy автоматически переключает трафик при отказе узла
   - RAS кластер поддерживает работу в режиме active-passive

## 🛠️ Требования

- Docker 20.10+
- Docker Compose 2.0+
- Ansible 2.9+ (опционально)
- Terraform 1.0+ (опционально)
- Минимум 8 GB RAM
- Минимум 2 CPU ядра
- 50 GB свободного места на диске

## 📝 Лицензия

Данный проект предоставляется "как есть" для образовательных и тестовых целей.

## 🔗 Полезные ссылки

- [Документация 1С](https://users.v8.1c.ru/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [HAProxy Documentation](https://www.haproxy.org/documentation/)
