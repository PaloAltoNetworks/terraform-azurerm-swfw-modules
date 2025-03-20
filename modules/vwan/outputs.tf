output "virtual_wan_ids" {
  description = "A map of identifiers for the created or sourced Virtual Wans."
  value = merge(
    { for k, v in azurerm_virtual_wan.this : k => v.id },
    { for k, v in data.azurerm_virtual_wan.this : k => v.id }
  )
}

output "virtual_hub_ids" {
  description = "A map of identifiers for the created or sourced Virtual Hubs."
  value = merge(
    { for k, v in azurerm_virtual_hub.this : k => v.id },
    { for k, v in data.azurerm_virtual_hub.this : k => v.id }
  )
}
