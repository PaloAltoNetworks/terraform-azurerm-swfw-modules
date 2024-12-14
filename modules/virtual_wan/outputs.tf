output "virtual_wan_id" {
  description = "The identifier of the created or sourced Virtual WAN."
  value       = local.virtual_wan.id
}

output "virtual_hub_ids" {
  description = "A map of identifiers for the created or sourced Virtual Hubs."
  value       = { for k, v in local.virtual_hubs : k => v.id }
}

output "route_table_ids" {
  description = "A map of identifiers for the created or sourced Virtual Hubs."
  value       = { for k, v in local.route_tables : k => v.id }
}

output "connections_ids" {
  description = "A map of identifiers for the created connections to Virtual Hubs."
  value       = { for k, v in local.connections : k => v.id }
}



