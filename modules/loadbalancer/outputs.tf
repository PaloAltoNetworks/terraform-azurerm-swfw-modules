output "id" {
  description = "The identifier of the Load Balancer resource."
  value       = azurerm_lb.this.id
}

output "backend_pool_id" {
  description = "The identifier of the backend pool."
  value       = azurerm_lb_backend_address_pool.this.id
}

output "frontend_ip_configs" {
  description = <<-EOF
  Map of IP prefixes/addresses, one per each entry of `frontend_ips` input. Contains public IP prefix/address for the frontends
  that have it, private IP address otherwise.
  EOF
  value       = local.frontend_addresses
}

output "health_probe" {
  description = "The health probe object."
  value       = azurerm_lb_probe.this
}
