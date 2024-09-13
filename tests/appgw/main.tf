# Create or source a Resource Group

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "${var.name_prefix}${var.resource_group_name}"
  location = var.region

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group = var.create_resource_group ? azurerm_resource_group.this[0] : data.azurerm_resource_group.this[0]
}

# Create a public IP in order to reuse it in one of the Application Gateways

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  name                = "pip-existing"
  resource_group_name = local.resource_group.name
  location            = var.region

  sku               = "Standard"
  allocation_method = "Static"
  zones             = ["1", "2", "3"]
  tags              = var.tags
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
  dns_servers   = each.value.dns_servers

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

module "public_ip" {
  source = "../../modules/public_ip"

  region = var.region
  public_ip_addresses = {
    for k, v in var.public_ips.public_ip_addresses : k => merge(v, {
      name                = "${var.name_prefix}${v.name}"
      resource_group_name = coalesce(v.resource_group_name, local.resource_group.name)
    })
  }
  public_ip_prefixes = {
    for k, v in var.public_ips.public_ip_prefixes : k => merge(v, {
      name                = "${var.name_prefix}${v.name}"
      resource_group_name = coalesce(v.resource_group_name, local.resource_group.name)
    })
  }

  tags = var.tags
}

# Create Application Gateways

module "appgw" {
  source = "../../modules/appgw"

  for_each = var.appgws

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = local.resource_group.name
  region              = var.region
  subnet_id           = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]

  zones = each.value.zones
  public_ip = merge(
    each.value.public_ip,
    {
      name = try("${each.value.public_ip.create ? var.name_prefix : ""}${each.value.public_ip.name}", null)
      id   = try(module.public_ip.pip_ids[each.value.public_ip.key], null)
    }
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
