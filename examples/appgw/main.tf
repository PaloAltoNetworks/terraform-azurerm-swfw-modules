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

# Create public IP in order to reuse it in 1 of the application gateways
resource "azurerm_public_ip" "this" {
  name                = "pip-existing"
  resource_group_name = local.resource_group.name
  location            = var.location

  sku               = "Standard"
  allocation_method = "Static"
  zones             = ["1", "2", "3"]
  tags              = var.tags
}

# Manage the network required for the topology.
module "vnet" {
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = each.value.create_virtual_network ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  location               = var.location

  address_space = each.value.address_space

  create_subnets = each.value.create_subnets
  subnets        = each.value.subnets

  network_security_groups = { for k, v in each.value.network_security_groups : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }
  route_tables = { for k, v in each.value.route_tables : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }

  tags = var.tags
}

# Create Application Gateway
module "appgw" {
  source = "../../modules/appgw"

  for_each = var.appgws

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = local.resource_group.name
  location            = var.location
  subnet_id           = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]

  zones = each.value.zones
  public_ip = merge(
    each.value.public_ip,
    { name = "${each.value.public_ip.create ? var.name_prefix : ""}${each.value.public_ip.name}" }
  )
  domain_name_label              = each.value.domain_name_label
  capacity                       = each.value.capacity
  enable_http2                   = each.value.enable_http2
  waf                            = each.value.waf
  managed_identities             = each.value.managed_identities
  global_ssl_policy              = each.value.global_ssl_policy
  ssl_profiles                   = each.value.ssl_profiles
  frontend_ip_configuration_name = each.value.frontend_ip_configuration_name
  listeners                      = each.value.listeners
  backend_pool                   = each.value.backend_pool
  backend_settings               = each.value.backend_settings
  probes                         = each.value.probes
  rewrites                       = each.value.rewrites
  redirects                      = each.value.redirects
  url_path_maps                  = each.value.url_path_maps
  rules                          = each.value.rules

  tags       = var.tags
  depends_on = [module.vnet, azurerm_public_ip.this]
}