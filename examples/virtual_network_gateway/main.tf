# Create or source the Resource Group.
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "${var.name_prefix}${var.resource_group_name}"
  location = var.location

  tags = var.tags
}

data "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group = var.create_resource_group ? azurerm_resource_group.this[0] : data.azurerm_resource_group.this[0]
}

module "vnet" { # REFACTOR copy the vnet invocation from other examples
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = "${var.name_prefix}${each.value.name}"
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  location               = var.location

  address_space = each.value.address_space

  create_subnets          = each.value.create_subnets
  subnets                 = each.value.subnets
  network_security_groups = each.value.network_security_groups
  route_tables            = each.value.route_tables

  tags = var.tags
}

# Create virtual network gateway
module "vng" {
  source = "../../modules/virtual_network_gateway"

  for_each = var.virtual_network_gateways

  name                = "${var.name_prefix}${each.value.name}"
  location            = var.location
  resource_group_name = local.resource_group.name

  network = merge(
    each.value.network,
    { subnet_id = module.vnet[each.value.network.vnet_key].subnet_ids[each.value.network.subnet_key] }
  )

  virtual_network_gateway  = each.value.virtual_network_gateway
  azure_bgp_peer_addresses = each.value.azure_bgp_peer_addresses
  bgp                      = each.value.bgp
  local_network_gateways   = each.value.local_network_gateways
  vpn_clients              = each.value.vpn_clients

  tags = var.tags
}