#!/bin/bash
# Скрипт инициализации базы данных для 1С

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Создание пользователя для 1С
    CREATE USER usr1cv WITH PASSWORD 'usr1cv_password';
    
    -- Создание базы данных для 1С
    CREATE DATABASE db1c OWNER usr1cv ENCODING 'UTF8' LC_COLLATE='ru_RU.UTF-8' LC_CTYPE='ru_RU.UTF-8';
    
    -- Предоставление прав
    GRANT ALL PRIVILEGES ON DATABASE db1c TO usr1cv;
    
    -- Настройка параметров для 1С
    ALTER DATABASE db1c SET lc_collate TO 'ru_RU.UTF-8';
    ALTER DATABASE db1c SET lc_ctype TO 'ru_RU.UTF-8';
    
    -- Создание пользователя для репликации
    CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator123';
    
    -- Создание слота репликации
    SELECT pg_create_physical_replication_slot('replication_slot');
EOSQL

echo "База данных успешно инициализирована для 1С"
