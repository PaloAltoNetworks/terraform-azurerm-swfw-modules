output "pip_ids" {
  description = "The identifiers of the created or sourced Public IP Addresses."
  value       = { for k, v in local.public_ip_addresses : k => v.id }
}

output "pip_ip_addresses" {
  description = "The IP values of the created or sourced Public IP Addresses."
  value       = { for k, v in local.public_ip_addresses : k => v.ip_address }
}

output "ippre_ids" {
  description = "The identifiers of the created or sourced Public IP Prefixes."
  value       = { for k, v in local.public_ip_prefixes : k => v.id }
}

output "ippre_ip_prefixes" {
  description = "The IP values of the created or sourced Public IP Prefixes."
  value       = { for k, v in local.public_ip_prefixes : k => v.ip_prefix }
}
