output "virtual_hub_id" {
  description = "The identifier of the created or sourced Virtual HUB."
  value       = local.virtual_hub.id
}

output "route_table_ids" {
  description = "A map of identifiers for the created Route Tables."
  value       = { for k, v in azurerm_virtual_hub.this : k => v.id }
}




