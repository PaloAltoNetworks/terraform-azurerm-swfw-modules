# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_wan
resource "azurerm_virtual_wan" "this" {
  count = var.create_virtual_wan ? 1 : 0

  name                           = var.virtual_wan_name
  resource_group_name            = var.resource_group_name
  location                       = var.region
  disable_vpn_encryption         = var.disable_vpn_encryption
  allow_branch_to_branch_traffic = var.allow_branch_to_branch_traffic
  type                           = "Standard"
  tags                           = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_wan
data "azurerm_virtual_wan" "this" {
  count               = var.create_virtual_wan == false ? 1 : 0
  name                = var.virtual_wan_name
  resource_group_name = var.resource_group_name
}

locals {
  virtual_wan = var.create_virtual_wan ? azurerm_virtual_wan.this[0] : data.azurerm_virtual_wan.this[0]
}
