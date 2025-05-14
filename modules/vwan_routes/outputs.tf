output "routing_intent_ids" {
  description = "The identifiers of the created Virtual Hub Routing Intents."
  value       = { for k, v in azurerm_virtual_hub_routing_intent.this : k => v.id }
}

output "route_ids" {
  description = "The identifiers of the created Routes within Virtual Hub Route Table."
  value       = { for k, v in azurerm_virtual_hub_route_table_route.this : k => v.id }
}
