
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

# output "cngfws_ips" {
#   description = "IP Addresses of the CNGFWs."
#   value       = { for k, v in module.cngfw : k => v.cngfw_public_ip_address }
# }

