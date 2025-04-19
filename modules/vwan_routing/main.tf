#https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/resources/virtual_hub_routing_intent
resource "azurerm_virtual_hub_routing_intent" "this" {
  name           = var.routing_intent.routing_intent_name
  virtual_hub_id = var.virtual_hub_id

  dynamic "routing_policy" {
    for_each = var.routing_intent.routing_policy
    content {
      name         = routing_policy.value.routing_policy_name
      destinations = routing_policy.value.destinations
      next_hop     = routing_policy.value.next_hop_id
    }
  }
}


