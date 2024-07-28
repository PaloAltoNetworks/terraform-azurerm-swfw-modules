output "vng_public_ips" {
  description = "IP Addresses of the VNGs."
  value = length(var.virtual_network_gateways) > 0 ? { for k, v in var.virtual_network_gateways : k => {
    primary = try(
      module.public_ip.pip_ip_addresses[v.ip_configurations.primary.public_ip_key],
      module.vng[k].public_ip[v.ip_configurations.primary.name],
      null
    )
    secondary = try(
      module.public_ip.pip_ip_addresses[v.ip_configurations.secondary.public_ip_key],
      module.vng[k].public_ip[v.ip_configurations.secondary.name],
      null
    )
  } } : null
}

output "vng_ipsec_policy" {
  description = "IPsec policy used for Virtual Network Gateway connection"
  value       = length(var.virtual_network_gateways) > 0 ? { for k, v in module.vng : k => v.ipsec_policy } : null
}
