# PlantUML-диаграммы для дипломной работы

## Список диаграмм

| Файл | Тип | Описание |
|------|-----|----------|
| `01-architecture.puml` | Component Diagram | Общая архитектура отказоустойчивого кластера |
| `02-failover-sequence.puml` | Sequence Diagram | Сценарий ручного failover PostgreSQL |
| `03-backup-sequence.puml` | Sequence Diagram | Сценарий резервного копирования |
| `04-deployment.puml` | Deployment Diagram | Диаграмма развёртывания на физические серверы |
| `05-network.puml` | Network Diagram | Сетевая топология (nwdiag) |

## Как использовать в Notepad++

1. Установите плагин **PlantUML Viewer** или используйте **PlantUML Offline**:
   - `Plugins` → `Plugin Admin` → найдите `PlantUML Viewer` → `Install`

2. Откройте любой `.puml` файл

3. Для предпросмотра:
   - `Plugins` → `PlantUML Viewer` → `Show PlantUML Window`

4. Для экспорта в PNG/SVG/PDF:
   - Установите Java JDK и Graphviz (`sudo apt install graphviz default-jdk`)
   - Скачайте `plantuml.jar` с https://plantuml.com/download
   - Конвертация: `java -jar plantuml.jar 01-architecture.puml`

## Альтернативные способы рендеринга

### Онлайн (без установки)
- https://www.plantuml.com/plantuml/uml/
- Просто скопируйте текст `.puml` файла

### VS Code
- Установите расширение **PlantUML**
- Откройте `.puml` файл → `Alt+D` для предпросмотра

### Командная строка (Linux)
```bash
sudo apt install graphviz default-jdk
wget https://github.com/plantuml/plantuml/releases/download/v1.2024.0/plantuml-1.2024.0.jar -O plantuml.jar

# PNG
java -jar plantuml.jar docs/diagrams/01-architecture.puml

# SVG
java -jar plantuml.jar -tsvg docs/diagrams/01-architecture.puml

# PDF
java -jar plantuml.jar -tpdf docs/diagrams/01-architecture.puml

# Все сразу
java -jar plantuml.jar docs/diagrams/*.puml
```

## Скриншоты рабочих сайтов (для диплома)

После запуска кластера сделайте скриншоты следующих страниц:

| Сервис | URL | Что снимать |
|--------|-----|-------------|
| Grafana Dashboard | `http://SERVER_IP:3000/d/1c-cluster` | Дашборд с метриками кластера |
| Grafana Login | `http://SERVER_IP:3000/login` | Страница входа |
| Prometheus Targets | `http://SERVER_IP:9090/targets` | Список целей сбора метрик |
| Prometheus Graph | `http://SERVER_IP:9090/graph` | Построение графика метрики |
| Alertmanager | `http://SERVER_IP:9093` | Список активных алертов |
| HAProxy Stats | `http://SERVER_IP:8404/stats` | Статистика балансировки |
| Docker Containers | `docker ps` в терминале | Список запущенных контейнеров |
| PostgreSQL Replication | `SELECT * FROM pg_stat_replication;` | Статус репликации |

### Как сделать скриншоты на Ubuntu сервере без GUI

```bash
# 1. Установите утилиту для скриншотов
sudo apt install -y chromium-browser xvfb cutycapt

# 2. Запустите виртуальный дисплей
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# 3. Сделайте скриншот страницы
cutycapt --url=http://localhost:3000 --out=grafana.png --min-width=1920 --min-height=1080

# 4. Или используйте Python + Selenium
sudo apt install -y python3-pip
pip3 install selenium webdriver-manager
python3 -c "
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
options = Options()
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--window-size=1920,1080')
driver = webdriver.Chrome(options=options)
driver.get('http://localhost:3000/login')
driver.save_screenshot('grafana_login.png')
driver.quit()
"
```

### Проще — через SSH-туннель на вашем ПК
```bash
# На вашем ПК (Windows / Linux)
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 -L 8404:localhost:8404 user@server-ip

# Откройте в браузере вашего ПК:
# http://localhost:3000
# http://localhost:9090
# http://localhost:8404
# И сделайте скриншоты стандартными средствами ОС
```
