output "vm_private_ips" {
  description = "A map of private IPs assigned to test VMs."
  value       = { for k, v in azurerm_network_interface.vm : k => v.private_ip_address }
}

output "frontend_ip_configs" {
  description = <<-EOF
  Map of IP addresses, one per each entry of `frontend_ips` input. Contains public IP address for the frontends that have it,
  private IP address otherwise.
  EOF
  value       = { for k, v in module.load_balancer : k => v.frontend_ip_configs }
}
