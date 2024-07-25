output "pip_ids" {
  description = "The identifiers of the created or sourced Public IP Addresses."
  value       = { for k, v in local.public_ips : k => v.id }
}

output "ippre_ids" {
  description = "The identifiers of the created or sourced Public IP Prefixes."
  value       = { for k, v in local.public_ip_prefixes : k => v.id }
}
