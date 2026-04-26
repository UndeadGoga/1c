terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.99"
    }
  }
  required_version = ">= 1.5.0"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.zone
}

# =============================================================================
# Сеть и подсети
# =============================================================================
resource "yandex_vpc_network" "main" {
  name = "1c-cluster-network"
}

resource "yandex_vpc_subnet" "app" {
  name           = "app-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.20.0/24"]
}

resource "yandex_vpc_subnet" "db" {
  name           = "db-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.30.0/24"]
}

resource "yandex_vpc_subnet" "monitoring" {
  name           = "monitoring-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.40.0/24"]
}

# =============================================================================
# 1С Серверы
# =============================================================================
resource "yandex_compute_instance" "server_1c" {
  count       = 2
  name        = "1c-server-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 4
    memory        = 8
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.app.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = <<-EOF
      #cloud-config
      timezone: Europe/Moscow
      package_update: true
      packages:
        - docker.io
        - docker-compose
      runcmd:
        - systemctl enable docker
        - systemctl start docker
    EOF
  }
}

# =============================================================================
# PostgreSQL серверы
# =============================================================================
resource "yandex_compute_instance" "postgres" {
  count       = 2
  name        = "postgres-${count.index == 0 ? "primary" : "replica"}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 4
    memory        = 8
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 100
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.db.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

# =============================================================================
# Мониторинг
# =============================================================================
resource "yandex_compute_instance" "monitoring" {
  name        = "monitoring"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.monitoring.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}
