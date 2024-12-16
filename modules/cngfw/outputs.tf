output "palo_alto_virtual_network_appliance_ids" {
  description = "The identifiers of the created Palo Alto Virtual Network Appliances."
  value       = { for k, v in azurerm_palo_alto_virtual_network_appliance.this : k => v.id }
}






