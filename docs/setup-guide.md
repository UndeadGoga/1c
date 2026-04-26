# Руководство по развёртыванию

## Содержание

1. [Подготовка окружения](#1-подготовка-окружения)
2. [Подготовка дистрибутива 1С](#2-подготовка-дистрибутива-1с)
3. [Развёртывание через Docker Compose](#3-развёртывание-через-docker-compose)
4. [Проверка работоспособности](#4-проверка-работоспособности)
5. [Нагрузочное тестирование](#5-нагрузочное-тестирование)
6. [Тест отказоустойчивости](#6-тест-отказоустойчивости)
7. [Автоматизация через Ansible](#7-автоматизация-через-ansible)
8. [Автоматизация через Terraform](#8-автоматизация-через-terraform)

---

## 1. Подготовка окружения

### 1.1. Системные требования

- **ОС хоста:** Ubuntu 22.04 LTS (x86_64)
- **Docker:** 24.0+ с Docker Compose plugin (v2)
- **RAM:** минимум 4 GB, рекомендуется 8 GB
- **Диск:** минимум 30 GB свободного места

### 1.2. Установка Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверка
docker --version
docker compose version
```

---

## 2. Подготовка дистрибутива 1С

> **Важно:** установщик 1С интерактивный и не поддерживает автоматическую установку в Docker.
> 1С устанавливается прямо на Ubuntu-хост, а затем файлы копируются в Docker-образ.

### 2.1. Скачайте дистрибутив

С портала 1С (releases.1c.ru) скачайте:
- **1С:Предприятие 8.3 Community Edition** — `server64_8_3_27_1936.zip`

Распакуйте и запустите установщик на сервере:
```bash
cd /путь/к/diplom/docker/1c-server/dist
unzip server64_8_3_27_1936.zip
sudo ./setup-full-8.3.27.1936-x86_64.run
```

В процессе установки:
- Выберите русский язык (код 17)
- Примите лицензионное соглашение
- Дождитесь окончания установки (файлы появятся в `/opt/1cv8`)

### 2.2. Скопируйте файлы в проект

```bash
cd /путь/к/diplom
bash scripts/prepare-1c-dist.sh
# Или вручную:
# sudo cp -r /opt/1cv8 docker/1c-server/dist/opt-1cv8
# sudo chown -R $USER:$USER docker/1c-server/dist/opt-1cv8
```

Убедитесь, что файлы на месте:
```bash
ls docker/1c-server/dist/opt-1cv8/x86_64/
```

---

## 3. Развёртывание через Docker Compose

Проект использует единый корневой `docker-compose.yml`, который объединяет три compose-файла через `include`:
- `postgres/docker-compose.yml` — PostgreSQL Primary + Replica
- `docker/docker-compose.yml` — 1С-серверы, HAProxy, RAS
- `monitoring/docker-compose.yml` — Prometheus, Grafana, Alertmanager, exporters

### 3.1. Сборка и запуск

```bash
cd /путь/к/diplom

# Сборка всех образов
make build
# или: docker compose build

# Запуск всей инфраструктуры
make up
# или: docker compose up -d

# Ждём инициализации (особенно pg_basebackup для реплики)
sleep 15
```

### 3.2. Проверка запущенных контейнеров

```bash
make ps
# или: docker compose ps
```

Должны быть запущены:
- `postgres-primary`, `postgres-replica`
- `1c-server-1`, `1c-server-2`, `1c-ras`
- `haproxy`
- `prometheus`, `grafana`, `alertmanager`
- `node-exporter`, `postgres-exporter`, `blackbox-exporter`, `cadvisor`

---

## 4. Проверка работоспособности

### 4.1. Быстрая проверка здоровья

```bash
make test
# или: bash scripts/health-check.sh
```

Проверяет:
- PostgreSQL Primary (запись, подключения)
- PostgreSQL Replica (standby-режим)
- Репликацию (lag)
- 1С-серверы (ragent, rmngr, rphost)
- HAProxy (статистика)
- Мониторинг (Prometheus, Grafana)

### 4.2. Проверка репликации PostgreSQL

```bash
# На Primary — список репликационных подключений
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# На Replica — режим recovery
docker exec postgres-replica psql -U postgres -c "SELECT pg_is_in_recovery();"
# Ожидается: t

# Лаг репликации
docker exec postgres-primary psql -U postgres -c "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;"
```

### 4.3. Проверка HAProxy

```bash
# Статистика в браузере
curl -u admin:admin http://localhost:8404/stats
```

Должно быть:
- `1c-server-1` — UP
- `1c-server-2` — UP (backup)
- `1c-ras` — UP

### 4.4. Доступ к интерфейсам мониторинга

| Сервис | URL | Логин / Пароль |
|--------|-----|----------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |

---

## 5. Нагрузочное тестирование

### 5.1. Нагрузка PostgreSQL через pgbench

```bash
make load-test
# или: bash scripts/load-test-pg.sh
```

По умолчанию:
- 10 клиентов
- 1000 транзакций на клиента
- Масштаб 10 (1 млн строк)

**Параметры:**
```bash
SCALE=50 CLIENTS=20 TRANSACTIONS=5000 bash scripts/load-test-pg.sh
```

Скрипт автоматически:
1. Устанавливает `postgresql-contrib` в контейнер (если нужно)
2. Создаёт тестовые данные (`pgbench -i`)
3. Запускает нагрузку
4. Проверяет лаг репликации после теста

### 5.2. Мониторинг нагрузки в Grafana

Во время нагрузки откройте Grafana → дашборд "1C Cluster" и наблюдайте:
- CPU/RAM контейнеров
- Количество подключений к PostgreSQL
- Replication lag
- Сетевой трафик

---

## 6. Тест отказоустойчивости

### 6.1. Failover PostgreSQL

```bash
make pg-failover
# или: bash scripts/test-failover.sh
```

Что делает скрипт:
1. Проверяет исходное состояние (Primary = запись, Replica = standby)
2. Останавливает Primary (`docker stop postgres-primary`)
3. Выполняет `pg_ctl promote` на Replica
4. Проверяет запись в новый Primary
5. Восстанавливает старый Primary через `pg_basebackup`

### 6.2. Отказоустойчивость HAProxy

```bash
make ha-failover
# или: bash scripts/test-haproxy-failover.sh
```

Что делает скрипт:
1. Проверяет исходное состояние HAProxy (все UP)
2. Останавливает `1c-server-1`
3. Проверяет, что HAProxy помечает сервер как DOWN
4. Проверяет доступность портов 1540/1541 (через `1c-server-2`)
5. Восстанавливает `1c-server-1`

---

## 7. Автоматизация через Ansible

### 7.1. Инвентарь

Отредактируйте `ansible/inventory/hosts.yml` под свои IP.

### 7.2. Запуск

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbook.yml
```

### 7.3. Теги

```bash
ansible-playbook -i inventory/hosts.yml playbook.yml --tags docker
ansible-playbook -i inventory/hosts.yml playbook.yml --tags postgres
ansible-playbook -i inventory/hosts.yml playbook.yml --tags monitoring
```

---

## 8. Автоматизация через Terraform

### 8.1. Провайдер (Yandex Cloud)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте переменные
```

### 8.2. Развёртывание

```bash
terraform init
terraform plan
terraform apply
```

### 8.3. Вывод IP

```bash
terraform output
```

---

## 9. Полезные команды Makefile

| Команда | Описание |
|---------|----------|
| `make up` | Запуск всей инфраструктуры |
| `make down` | Остановка |
| `make build` | Сборка всех образов |
| `make ps` | Статус контейнеров |
| `make logs` | Логи в реальном времени |
| `make test` | Проверка здоровья |
| `make status` | Полный отчёт |
| `make load-test` | Нагрузка PostgreSQL |
| `make pg-failover` | Тест failover PostgreSQL |
| `make ha-failover` | Тест HAProxy |
| `make clean` | Удаление контейнеров и volumes |
