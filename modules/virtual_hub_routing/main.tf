resource "azurerm_virtual_hub_routing_intent" "this" {
  count = !var.advanced_routing ? 1 : 0

  name           = var.routing_intent.routing_intent_name
  virtual_hub_id = var.virtual_hub_ids[var.routing_intent.virtual_hub_key]

  dynamic "routing_policy" {
    for_each = var.routing_intent.routing_policy
    content {
      name         = routing_policy.value.routing_policy_name
      destinations = routing_policy.value.destinations
      next_hop     = var.next_hops[routing_policy.value.next_hop_key]
    }
  }
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_route_table_route
resource "azurerm_virtual_hub_route_table_route" "this" {
  count          = var.advanced_routing && var.routes != null ? length(var.routes) : 0
  route_table_id = var.route_table_ids[var.routes[count.index].route_table_key]

  name              = var.routes[count.index].route_name
  destinations_type = var.routes[count.index].destinations_type
  destinations      = var.routes[count.index].destinations
  next_hop_type     = var.routes[count.index].next_hop_type
  next_hop          = var.next_hops[var.routes[count.index].nex_hop_key]
}

