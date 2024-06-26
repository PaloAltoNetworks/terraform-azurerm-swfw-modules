output "mgmt_ip_address" {
  description = <<-EOF
  Panorama management IP address. If `public_ip` was `true`, it is a public IP address, otherwise a private IP address.
  EOF
  value = try(
    azurerm_public_ip.this[var.interfaces[0].name].ip_address,
    azurerm_network_interface.this[var.interfaces[0].name].ip_configuration[0].private_ip_address
  )
}

output "interfaces" {
  description = "Map of VM-Series network interfaces. Keys are equal to var.interfaces `name` properties."
  value       = azurerm_network_interface.this
}
