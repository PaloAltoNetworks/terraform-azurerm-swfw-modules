# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip_prefix
data "azurerm_public_ip_prefix" "allocate" {
  for_each = { for k, v in var.public_ip_addresses : k => v if v.create && v.prefix_name != null }

  name                = each.value.prefix_name
  resource_group_name = each.value.prefix_resource_group_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  for_each = { for k, v in var.public_ip_addresses : k => v if v.create }

  name                    = each.value.name
  resource_group_name     = each.value.resource_group_name
  location                = var.region
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = each.value.zones
  domain_name_label       = each.value.domain_name_label
  idle_timeout_in_minutes = each.value.idle_timeout_in_minutes
  public_ip_prefix_id     = try(data.azurerm_public_ip_prefix.allocate[each.key].id, null)
  tags                    = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  for_each = { for k, v in var.public_ip_addresses : k => v if !v.create }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip_prefix
resource "azurerm_public_ip_prefix" "this" {
  for_each = { for k, v in var.public_ip_prefixes : k => v if v.create }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = var.region
  ip_version          = "IPv4"
  prefix_length       = each.value.length
  sku                 = "Standard"
  zones               = each.value.zones

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip_prefix
data "azurerm_public_ip_prefix" "this" {
  for_each = { for k, v in var.public_ip_prefixes : k => v if !v.create }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

locals {
  public_ip_addresses = merge(azurerm_public_ip.this, data.azurerm_public_ip.this)
  public_ip_prefixes  = merge(azurerm_public_ip_prefix.this, data.azurerm_public_ip_prefix.this)
}
