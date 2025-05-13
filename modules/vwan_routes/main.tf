#https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/resources/virtual_hub_routing_intent
resource "azurerm_virtual_hub_routing_intent" "this" {
  for_each       = var.routing_intent
  name           = each.value.routing_intent.routing_intent_name
  virtual_hub_id = each.value.virtual_hub_id

  dynamic "routing_policy" {
    for_each = each.value.routing_intent.routing_policy
    content {
      name         = routing_policy.value.routing_policy_name
      destinations = routing_policy.value.destinations
      next_hop     = routing_policy.value.next_hop_id
    }
  }
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_route_table_route
resource "azurerm_virtual_hub_route_table_route" "this" {
  for_each          = var.routes
  route_table_id    = each.value.route_table_id
  name              = each.value.name
  destinations_type = each.value.destinations_type
  destinations      = each.value.destinations
  next_hop_type     = each.value.next_hop_type
  next_hop          = each.value.next_hop_id
}