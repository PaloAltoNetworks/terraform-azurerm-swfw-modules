output "virtual_wan_id" {
  description = "The identifier of the created or sourced Virtual WAN."
  value       = local.virtual_wan.id
}

output "virtual_hub_ids" {
  description = "The identifier of the created or sourced Virtual Hub."
  value = merge({ for k, v in azurerm_virtual_hub.this : k => v.id },
  { for k, v in data.azurerm_virtual_hub.this : k => v.id })
}

output "route_table_ids" {
  description = "A map of identifiers for the created Route Tables."
  value       = { for k, v in azurerm_virtual_hub_route_table.this : k => v.id }
}


