-- Скрипт инициализации для Primary узла PostgreSQL
-- Настраивает репликацию и права доступа

-- Создание пользователя для репликации
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator123';

-- Настройка прав для основной базы (если нужно расширить)
GRANT ALL PRIVILEGES ON DATABASE demo_db TO postgres;

-- Примечание:
-- Физическая репликация настраивается через pg_hba.conf и параметры запуска,
-- которые передаются через переменные окружения в docker-compose.
-- Этот скрипт выполняется только при первом создании контейнера primary.
