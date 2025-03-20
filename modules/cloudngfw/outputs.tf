output "palo_alto_virtual_network_appliance_id" {
  description = "The identifier of the created Palo Alto Virtual Network Appliance."
  value       = length(azurerm_palo_alto_virtual_network_appliance.this) > 0 ? azurerm_palo_alto_virtual_network_appliance.this[0].id : null
}
