output "usernames" {
  description = "Initial administrative username to use for VM-Series."
  value       = { for k, v in local.authentication : k => v.username }
}

output "passwords" {
  description = "Initial administrative password to use for VM-Series."
  value       = { for k, v in local.authentication : k => v.password }
  sensitive   = true
}

output "natgw_public_ips" {
  description = "Nat Gateways Public IP resources."
  value = length(var.natgws) > 0 ? { for k, v in var.natgws : k => {
    pip        = try(coalesce(module.public_ip.pip_ip_addresses[v.public_ip.key], module.natgw[k].natgw_pip), null)
    pip_prefix = try(coalesce(module.public_ip.ippre_ip_prefixes[v.public_ip_prefix.key], module.natgw[k].natgw_pip_prefix), null)
  } } : null
}

output "metrics_instrumentation_keys" {
  description = "The Instrumentation Key of the created instance(s) of Azure Application Insights."
  value       = try(module.ngfw_metrics[0].metrics_instrumentation_keys, null)
  sensitive   = true
}

output "lb_frontend_ips" {
  description = "IP Addresses of the load balancers."
  value       = length(var.load_balancers) > 0 ? { for k, v in module.load_balancer : k => v.frontend_ip_configs } : null
}

output "vmseries_mgmt_ips" {
  description = "IP addresses for the VM-Series management interface."
  value = { for k, v in var.vmseries : k => coalesce(
    try(module.public_ip.pip_ip_addresses[v.interfaces[0].public_ip_key], null),
    module.vmseries[k].mgmt_ip_address
  ) }
}

output "bootstrap_storage_urls" {
  value     = length(var.bootstrap_storages) > 0 ? { for k, v in module.bootstrap : k => v.file_share_urls } : null
  sensitive = true
}

output "test_vms_usernames" {
  description = "Initial administrative username to use for test VMs."
  value = length(var.test_infrastructure) > 0 ? {
    for k, v in local.test_vm_authentication : k => v.username
  } : null
}

output "test_vms_passwords" {
  description = "Initial administrative password to use for test VMs."
  value = length(var.test_infrastructure) > 0 ? {
    for k, v in local.test_vm_authentication : k => v.password
  } : null
  sensitive = true
}

output "test_vms_ips" {
  description = "IP Addresses of the test VMs."
  value       = length(var.test_infrastructure) > 0 ? { for k, v in module.test_infrastructure : k => v.vm_private_ips } : null
}

output "test_lb_frontend_ips" {
  description = "IP Addresses of the test load balancers."
  value = length({ for k, v in var.test_infrastructure : k => v if v.load_balancers != null }) > 0 ? {
    for k, v in module.test_infrastructure : k => v.frontend_ip_configs
  } : null
}
