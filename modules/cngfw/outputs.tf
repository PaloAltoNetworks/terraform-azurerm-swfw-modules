output "palo_alto_virtual_network_appliance_ids" {
  description = "The identifiers of the created Palo Alto Virtual Network Appliances."
  value       = { for k, v in azurerm_palo_alto_virtual_network_appliance.this : k => v.id }
}

output "cngfw_public_ip_address" {
  description = "Public IP Addresses of the CNGFW"
  value       = var.cngfw_config.create_public_ip ? try(azurerm_public_ip.this[0].ip_address, null) : try(data.azurerm_public_ip.this[0].ip_address, null)
}





