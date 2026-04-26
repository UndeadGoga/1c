# Сценарии Disaster Recovery (DR)

## 1. Классификация сбоев

| Уровень | Сценарий | Время восстановления (RTO) | Потеря данных (RPO) |
|---------|----------|---------------------------|---------------------|
| 1 | Отказ рабочего процесса rphost | < 1 мин | 0 |
| 2 | Отказ сервера 1С | < 5 мин | 0 |
| 3 | Отказ PostgreSQL Primary | < 10 мин | ~0 (потоковая репликация) |
| 4 | Повреждение данных (логическое) | < 1 час | до последнего backup |
| 5 | Полный отказ ЦОД | < 4 часа | до последнего off-site backup |

---

## 2. Сценарий 1: Отказ рабочего процесса rphost

**Признаки:**
- Пользователи получают ошибку подключения.
- Мониторинг: процесс rphost отсутствует.

**Действия:**
1. `docker compose restart 1c-server-1`
2. Docker Compose перезапускает контейнер автоматически (`restart: unless-stopped`).

---

## 3. Сценарий 2: Отказ сервера 1С

**Признаки:**
- HAProxy помечает сервер как DOWN.
- Мониторинг: `probe_success == 0`.

**Действия:**
1. HAProxy автоматически перенаправляет трафик на резервный сервер (`1c-server-2` backup).
2. Администратор получает алерт.
3. Диагностика: `docker logs 1c-server-1`, проверка диска.
4. После восстановления — сервер возвращается в пул.

**Автоматический тест:**
```bash
bash scripts/test-haproxy-failover.sh
```

---

## 4. Сценарий 3: Отказ PostgreSQL Primary

**Признаки:**
- Мониторинг: `pg_up == 0`.
- Replication lag отсутствует.

**Действия (ручной failover):**

### Шаг 1: Проверить состояние Standby
```bash
docker exec postgres-replica psql -U postgres -c "SELECT pg_is_in_recovery();"
# Должно вернуть: t
```

### Шаг 2: Остановить Primary
```bash
docker compose stop postgres-primary
```

### Шаг 3: Promote Standby
```bash
docker exec -u postgres postgres-replica pg_ctl promote -D /var/lib/postgresql/data
```

### Шаг 4: Проверить
```bash
docker exec postgres-replica psql -U postgres -c "SELECT pg_is_in_recovery();"
# Должно вернуть: f
```

### Шаг 5: Переключить 1С на новый Primary
```bash
# Обновить переменные окружения в docker-compose и перезапустить
docker compose up -d
```

### Шаг 6: Восстановить старый Primary как Replica
```bash
docker exec postgres-primary bash -c "
  rm -rf /var/lib/postgresql/data/*
  export PGPASSWORD=repl_password
  pg_basebackup -h postgres-replica -D /var/lib/postgresql/data -U replicator -Fp -Xs -P -v
"
docker compose start postgres-primary
```

**Автоматический тест failover:**
```bash
bash scripts/test-failover.sh
```

---

## 5. Сценарий 4: Восстановление из резервной копии (PITR)

**Действия:**
1. Остановить PostgreSQL.
2. Создать резерв текущего состояния: `mv /var/lib/postgresql/data /var/lib/postgresql/data_corrupted`.
3. Восстановить из базовой копии.
4. Настроить `recovery_target_time` в `postgresql.conf`.
5. Запустить PostgreSQL.

---

## 6. Сценарий 5: Полный отказ ЦОД

**Действия:**
1. Активация DR-сайта через Terraform + Ansible.
2. Переключение DNS.
3. Восстановление из off-site backup (S3/MinIO).

---

## 7. Процедуры резервного копирования

### 7.1. PostgreSQL (pg_basebackup + WAL-архивация)

**Ежедневно (полный backup):**
```bash
docker exec postgres-primary pg_basebackup -D /backup/pg_base_$(date +%Y%m%d) -Ft -z -P
```

**Непрерывно (WAL-архивация):**
```ini
archive_mode = on
archive_command = 'test ! -f /backup/wal/%f && cp %p /backup/wal/%f'
archive_timeout = 300
```

### 7.2. Информационные базы 1С

**Через утилиту rac:**
```bash
docker exec -it 1c-ras rac infobase dump \
  --cluster=<uuid> \
  --infobase=<uuid> \
  --output=/backup/1c/my_db_$(date +%Y%m%d).dt
```

### 7.3. Хранение бэкапов

| Уровень | Место хранения | Срок |
|---------|---------------|------|
| Локальный | /backup | 7 дней |
| Сетевой | NFS / Samba | 30 дней |
| Облако | MinIO / AWS S3 Compatible | 1 год |

---

## 8. Тестирование DR

**Периодичность:** раз в квартал (или перед сдачей диплома).

**План:**
1. Симулировать отказ Primary (`bash scripts/test-failover.sh`).
2. Проверить переключение HAProxy (`bash scripts/test-haproxy-failover.sh`).
3. Нагрузить PostgreSQL (`bash scripts/load-test-pg.sh`).
4. Зафиксировать RTO и RPO.
5. Выполнить обратное переключение (`docker compose down -v && docker compose up -d`).
