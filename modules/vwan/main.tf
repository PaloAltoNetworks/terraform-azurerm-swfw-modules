# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_wan
resource "azurerm_virtual_wan" "this" {
  count = var.create_virtual_wan ? 1 : 0

  name                           = var.name
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
  name                = var.name
  resource_group_name = var.resource_group_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub
resource "azurerm_virtual_hub" "this" {
  for_each = { for k, v in var.virtual_hubs : k => v if v.create_virtual_hub }

  name                   = each.value.name
  resource_group_name    = coalesce(each.value.resource_group_name, var.resource_group_name)
  location               = coalesce(each.value.region, var.region)
  virtual_wan_id         = coalesce((var.create_virtual_wan ? azurerm_virtual_wan.this[0].id : data.azurerm_virtual_wan.this[0].id), each.value.virtual_wan_id)
  address_prefix         = each.value.address_prefix
  hub_routing_preference = each.value.hub_routing_preference
  sku                    = "Standard"
  tags                   = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_hub
data "azurerm_virtual_hub" "this" {
  for_each = { for k, v in var.virtual_hubs : k => v if !v.create_virtual_hub }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_route_table
resource "azurerm_virtual_hub_route_table" "this" {
  for_each       = { for k, v in var.route_tables : k => v if v.create_route_table }
  name           = each.value.name
  virtual_hub_id = merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id
  labels         = each.value.labels
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_hub_route_table
data "azurerm_virtual_hub_route_table" "this" {
  for_each            = { for k, v in var.route_tables : k => v if !v.create_route_table }
  name                = each.value.name
  resource_group_name = coalesce(each.value.resource_group_name, var.resource_group_name)
  virtual_hub_name    = each.value.virtual_hub_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_connection
resource "azurerm_virtual_hub_connection" "this" {
  for_each = { for k, v in var.connections : k => v if v.connection_type == "Vnet" }

  name                      = each.value.name
  virtual_hub_id            = merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id
  remote_virtual_network_id = var.remote_virtual_network_ids[each.value.remote_virtual_network_key]
  dynamic "routing" {
    for_each = each.value.routing != null ? [1] : []
    content {
      associated_route_table_id = (
        each.value.routing.associated_route_table_key == "none" ?
        format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "noneRouteTable") :
        each.value.routing.associated_route_table_key == "default" ?
        format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "defaultRouteTable") :
        merge(azurerm_virtual_hub_route_table.this, data.azurerm_virtual_hub_route_table.this)[each.value.routing.associated_route_table_key].id
      )
      propagated_route_table {
        labels = (
          contains(each.value.routing.propagated_route_table_labels, "none") ?
          ["none"] :
          contains(each.value.routing.propagated_route_table_labels, "default") ?
          ["default"] :
          each.value.routing.propagated_route_table_labels
        )
        route_table_ids = (
          contains(each.value.routing.propagated_route_table_keys, "none") ?
          [format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "noneRouteTable")] :
          contains(each.value.routing.propagated_route_table_keys, "default") ?
          [format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "defaultRouteTable")] :
          [for k in each.value.routing.propagated_route_table_keys : merge(azurerm_virtual_hub_route_table.this, data.azurerm_virtual_hub_route_table.this)[k].id]
        )
      }
      static_vnet_route {
        name                = each.value.routing.static_vnet_route_name
        address_prefixes    = each.value.routing.static_vnet_route_address_prefixes
        next_hop_ip_address = each.value.routing.static_vnet_route_next_hop_ip_address
      }
      static_vnet_local_route_override_criteria = each.value.routing.static_vnet_local_route_override_criteria
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/Azurerm/latest/docs/resources/vpn_gateway
resource "azurerm_vpn_gateway" "this" {
  count               = var.vpn_gateway != null ? 1 : 0
  name                = var.vpn_gateway.name
  location            = coalesce(var.vpn_gateway.region, var.region)
  resource_group_name = coalesce(var.vpn_gateway.resource_group_name, var.resource_group_name)
  virtual_hub_id      = merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[var.vpn_gateway.virtual_hub_key].id
  scale_unit          = var.vpn_gateway.scale_unit
  routing_preference  = var.vpn_gateway.routing_preference
  tags                = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_site
resource "azurerm_vpn_site" "this" {
  for_each            = { for k, v in var.vpn_sites : k => v }
  name                = each.value.name
  resource_group_name = coalesce(each.value.resource_group_name, var.resource_group_name)
  location            = coalesce(var.region, each.value.region)
  virtual_wan_id      = (var.create_virtual_wan ? azurerm_virtual_wan.this[0].id : data.azurerm_virtual_wan.this[0].id)
  address_cidrs       = each.value.address_cidrs

  dynamic "link" {
    for_each = each.value.link
    content {
      name          = link.value.name
      ip_address    = link.value.ip_address
      fqdn          = link.value.fqdn
      provider_name = link.value.provider_name
      speed_in_mbps = link.value.speed_in_mbps
    }
  }
}

locals {
  vpn_site_links_map = {
    for site_key, site in azurerm_vpn_site.this :
    site_key => {
      for index, link in site.link :
      link.name => link
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_gateway_connection
resource "azurerm_vpn_gateway_connection" "this" {
  for_each = { for k, v in var.connections : k => v if v.connection_type == "Site-to-Site" }

  name               = each.value.name
  vpn_gateway_id     = azurerm_vpn_gateway.this[0].id
  remote_vpn_site_id = azurerm_vpn_site.this[each.value.vpn_site_key].id
  dynamic "vpn_link" {
    for_each = each.value.vpn_link
    content {
      name                           = vpn_link.value.vpn_link_name
      vpn_site_link_id               = local.vpn_site_links_map[each.value.vpn_site_key][vpn_link.value.vpn_site_link_key].id
      bandwidth_mbps                 = vpn_link.value.bandwidth_mbps
      bgp_enabled                    = vpn_link.value.bgp_enabled
      connection_mode                = vpn_link.value.connection_mode
      protocol                       = vpn_link.value.protocol
      ratelimit_enabled              = vpn_link.value.ratelimit_enabled
      route_weight                   = vpn_link.value.route_weight
      shared_key                     = vpn_link.value.shared_key
      local_azure_ip_address_enabled = vpn_link.value.local_azure_ip_address_enabled
      ipsec_policy {
        dh_group                 = vpn_link.value.ipsec_policy.dh_group
        ike_encryption_algorithm = vpn_link.value.ipsec_policy.ike_encryption_algorithm
        ike_integrity_algorithm  = vpn_link.value.ipsec_policy.ike_integrity_algorithm
        encryption_algorithm     = vpn_link.value.ipsec_policy.encryption_algorithm
        integrity_algorithm      = vpn_link.value.ipsec_policy.integrity_algorithm
        pfs_group                = vpn_link.value.ipsec_policy.pfs_group
        sa_data_size_kb          = vpn_link.value.ipsec_policy.sa_data_size_kb
        sa_lifetime_sec          = vpn_link.value.ipsec_policy.sa_lifetime_sec
      }
    }
  }

  dynamic "routing" {
    for_each = each.value.routing != null ? [1] : []
    content {
      associated_route_table = (
        each.value.routing.associated_route_table_key == "none" ?
        format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "noneRouteTable") :
        each.value.routing.associated_route_table_key == "default" ?
        format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "defaultRouteTable") :
        merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id
      )
      propagated_route_table {
        labels = (
          contains(each.value.routing.propagated_route_table_labels, "none") ?
          ["none"] :
          contains(each.value.routing.propagated_route_table_labels, "default") ?
          ["default"] :
          each.value.routing.propagated_route_table_labels
        )
        route_table_ids = (
          contains(each.value.routing.propagated_route_table_keys, "none") ?
          [format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "noneRouteTable")] :
          contains(each.value.routing.propagated_route_table_keys, "default") ?
          [format("%s%s%s", merge(azurerm_virtual_hub.this, data.azurerm_virtual_hub.this)[each.value.virtual_hub_key].id, "/hubRouteTables/", "defaultRouteTable")] :
          [for k in each.value.routing.propagated_route_table_keys : merge(azurerm_virtual_hub_route_table.this, data.azurerm_virtual_hub_route_table.this)[k].id]
        )
      }
    }
  }
}
