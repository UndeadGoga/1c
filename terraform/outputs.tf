output "server_1c_ips" {
  description = "Внутренние IP серверов 1С"
  value       = yandex_compute_instance.server_1c[*].network_interface.0.ip_address
}

output "server_1c_nat_ips" {
  description = "Публичные IP серверов 1С"
  value       = yandex_compute_instance.server_1c[*].network_interface.0.nat_ip_address
}

output "postgres_primary_ip" {
  description = "Внутренний IP PostgreSQL Primary"
  value       = yandex_compute_instance.postgres[0].network_interface.0.ip_address
}

output "postgres_replica_ip" {
  description = "Внутренний IP PostgreSQL Replica"
  value       = yandex_compute_instance.postgres[1].network_interface.0.ip_address
}

output "monitoring_ip" {
  description = "Публичный IP сервера мониторинга"
  value       = yandex_compute_instance.monitoring.network_interface.0.nat_ip_address
}
