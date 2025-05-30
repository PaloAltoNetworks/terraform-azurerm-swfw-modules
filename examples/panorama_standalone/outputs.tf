output "username" {
  description = "Initial administrative username to use for Panorama."
  value       = { for k, v in local.authentication : k => v.username }
}

output "password" {
  description = "Initial administrative password to use for Panorama."
  value       = { for k, v in local.authentication : k => v.password }
  sensitive   = true
}

output "panorama_mgmt_ips" {
  description = "IP addresses for the Panorama management interface."
  value = { for k, v in var.panoramas : k => coalesce(
    try(module.public_ip.pip_ip_addresses[v.interfaces[0].public_ip_key], null),
    module.panorama[k].mgmt_ip_address
  ) }
}
