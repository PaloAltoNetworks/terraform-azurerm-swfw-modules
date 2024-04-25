# Generate a random password

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "${var.name_prefix}${var.resource_group_name}"
  location = var.region

  tags = var.tags
}

# Create or source a Resource Group

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group = var.create_resource_group ? azurerm_resource_group.this[0] : data.azurerm_resource_group.this[0]
}

# Manage the network required for the topology

module "vnet" {
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = each.value.create_virtual_network ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                 = var.region

  address_space = each.value.address_space

  create_subnets = each.value.create_subnets
  subnets        = each.value.subnets

  network_security_groups = {
    for k, v in each.value.network_security_groups : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }
  route_tables = {
    for k, v in each.value.route_tables : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }

  tags = var.tags
}

# Create Virtual Network Gateways

module "vng" {
  source = "../../modules/virtual_network_gateway"

  for_each = var.virtual_network_gateways

  name                = "${var.name_prefix}${each.value.name}"
  region              = var.region
  resource_group_name = local.resource_group.name

  subnet_id = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]

  zones                            = each.value.zones
  edge_zone                        = each.value.edge_zone
  instance_settings                = each.value.instance_settings
  ip_configurations                = each.value.ip_configurations
  private_ip_address_enabled       = each.value.private_ip_address_enabled
  default_local_network_gateway_id = each.value.default_local_network_gateway_id

  azure_bgp_peer_addresses = each.value.azure_bgp_peer_addresses
  bgp                      = each.value.bgp
  local_network_gateways   = each.value.local_network_gateways
  vpn_clients              = each.value.vpn_clients

  tags = var.tags
}
