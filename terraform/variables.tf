variable "yc_token" {
  description = "OAuth-токен Yandex Cloud"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "ID облака Yandex Cloud"
  type        = string
}

variable "yc_folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
}

variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "image_id" {
  description = "ID образа ОС (Ubuntu 22.04 LTS)"
  type        = string
  default     = "fd8pbf0hh1a25qe7i7l7"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "network_cidr" {
  description = "CIDR основной сети"
  type        = string
  default     = "10.0.0.0/16"
}
