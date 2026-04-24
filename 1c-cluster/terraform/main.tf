# Terraform конфигурация для локального развёртывания кластера 1С
# Примечание: Для локального развёртывания используется Docker provider

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Сеть для кластера
resource "docker_network" "1c_network" {
  name = "1c-network"
  driver = "bridge"
}

# PostgreSQL Primary
resource "docker_volume" "pg_primary_data" {
  name = "pg_primary_data"
}

resource "docker_image" "postgres" {
  name = "postgres:15-alpine"
  keep_locally = false
}

resource "docker_container" "pg_primary" {
  name  = "pg-primary"
  image = docker_image.postgres.image_id
  
  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=postgres123",
    "POSTGRES_DB=template1"
  ]
  
  volumes {
    volume_name    = docker_volume.pg_primary_data.name
    container_path = "/var/lib/postgresql/data"
  }
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  ports {
    internal = 5432
    external = 5432
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_network.1c_network]
}

# PostgreSQL Replica
resource "docker_volume" "pg_replica_data" {
  name = "pg_replica_data"
}

resource "docker_container" "pg_replica" {
  name  = "pg-replica"
  image = docker_image.postgres.image_id
  
  env = [
    "PGUSER=replicator",
    "PGPASSWORD=replicator123"
  ]
  
  command = [
    "bash", "-c",
    "until pg_basebackup --pgdata=/var/lib/postgresql/data -R --slot=replication_slot --host=pg-primary --port=5432 --username=replicator --verbose; do echo 'Waiting for primary...'; sleep 1s; done && chmod 0700 /var/lib/postgresql/data && postgres"
  ]
  
  volumes {
    volume_name    = docker_volume.pg_replica_data.name
    container_path = "/var/lib/postgresql/data"
  }
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_container.pg_primary]
}

# PgPool-II
resource "docker_container" "pgpool" {
  name  = "pgpool"
  image = "bitnami/pgpool:4.4"
  
  env = [
    "PGPOOL_BACKEND_NODES=0:pg-primary:5432,1:pg-replica:5432",
    "PGPOOL_POSTGRES_USERNAME=postgres",
    "PGPOOL_POSTGRES_PASSWORD=postgres123",
    "PGPOOL_ADMIN_USERNAME=admin",
    "PGPOOL_ADMIN_PASSWORD=admin123",
    "PGPOOL_ENABLE_LOAD_BALANCING=yes",
    "PGPOOL_FAILOVER_ON_BACKEND_ERROR=yes"
  ]
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  ports {
    internal = 5432
    external = 5433
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_container.pg_primary, docker_container.pg_replica]
}

# Prometheus
resource "docker_volume" "prometheus_data" {
  name = "prometheus_data"
}

resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = "prom/prometheus:v2.47.0"
  
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=15d",
    "--web.enable-lifecycle"
  ]
  
  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
    
    host_path = "${path.module}/monitoring/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only = true
  }
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  ports {
    internal = 9090
    external = 9090
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_network.1c_network]
}

# Grafana
resource "docker_volume" "grafana_data" {
  name = "grafana_data"
}

resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana:10.1.0"
  
  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin123"
  ]
  
  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  ports {
    internal = 3000
    external = 3000
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_container.prometheus]
}

# Node Exporter
resource "docker_container" "node_exporter" {
  name  = "node-exporter"
  image = "prom/node-exporter:v1.6.1"
  
  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)"
  ]
  
  volumes {
    host_path = "/proc"
    container_path = "/host/proc"
    read_only = true
    
    host_path = "/sys"
    container_path = "/host/sys"
    read_only = true
    
    host_path = "/"
    container_path = "/rootfs"
    read_only = true
  }
  
  networks_advanced {
    name = docker_network.1c_network.name
  }
  
  restart = "unless-stopped"
  
  depends_on = [docker_network.1c_network]
}

# Вывод информации
output "postgres_url" {
  value = "postgresql://postgres:postgres123@localhost:5433"
}

output "grafana_url" {
  value = "http://localhost:3000 (admin/admin123)"
}

output "prometheus_url" {
  value = "http://localhost:9090"
}
