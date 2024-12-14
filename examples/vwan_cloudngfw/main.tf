# Generate a random password

# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "this" {
  count = anytrue([for _, v in var.test_infrastructure : v.authentication.password == null]) ? 1 : 0


  length           = 16
  min_lower        = 16 - 4
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}

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

module "vnet" {
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = each.value.create_virtual_network ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                 = var.region
  address_space          = each.value.address_space

  tags = var.tags
}

locals {
  remote_virtual_network_ids = merge({ for entry in flatten([
    for val in { for k, v in module.test_infrastructure : k => v.vnet_ids } : [ #zmiana kv
      for k, v in val : {
        key = k
        val = v
      }
    ]
    ]) : entry.key => entry.val
  }, { for k, v in module.vnet : k => v.virtual_network_id })
}

#VWAN
module "virtual_wan" {
  source = "../../modules/virtual_wan"

  for_each = var.virtual_wans

  name                       = each.value.create_virtual_wan ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_wan         = each.value.create_virtual_wan
  resource_group_name        = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                     = var.region
  virtual_hubs               = each.value.virtual_hubs
  connections                = each.value.connections
  remote_virtual_network_ids = local.remote_virtual_network_ids
  vpn_gateways               = each.value.vpn_gateways
  vpn_sites                  = each.value.vpn_sites
  route_tables               = each.value.route_tables
  tags                       = var.tags
}

#CNGFW
module "cngfw" {
  source = "../../modules/cngfw"

  for_each = var.cngfws

  attachment_type             = each.value.attachment_type
  management_mode             = each.value.management_mode
  palo_alto_virtual_appliance = each.value.palo_alto_virtual_appliance
  cngfw_config                = each.value.cngfw_config
  resource_group_name         = local.resource_group.name
  region                      = var.region
  virtual_hub_id              = each.value.attachment_type == "vwan" ? module.virtual_wan[each.value.virtual_wan_key].virtual_hub_ids[each.value.virtual_hub_key] : null
  tags                        = var.tags
}

#VIRTUAL HUB ROUTING
module "virtual_hub_routing" {
  source = "../../modules/virtual_hub_routing"

  advanced_routing = var.virtual_hub_routing.advanced_routing
  routing_intent   = var.virtual_hub_routing.routing_intent
  routes           = var.virtual_hub_routing.routes
  virtual_hub_ids  = module.virtual_wan[var.virtual_hub_routing.virtual_wan_key].virtual_hub_ids
  next_hops        = module.cngfw[var.virtual_hub_routing.cngfw_key].palo_alto_virtual_network_appliance_ids
  route_table_ids  = module.virtual_wan[var.virtual_hub_routing.virtual_wan_key].route_table_ids
}



# Create test infrastructure
locals {
  test_vm_authentication = {
    for k, v in var.test_infrastructure : k =>
    merge(
      v.authentication,
      {
        password = coalesce(v.authentication.password, try(random_password.this[0].result, null))
      }
    )
  }
}

module "test_infrastructure" {
  source = "../../modules/test_infrastructure"

  for_each = var.test_infrastructure

  resource_group_name = try(
    "${var.name_prefix}${each.value.resource_group_name}", "${local.resource_group.name}-testenv"
  )
  region = var.region
  vnets = { for k, v in each.value.vnets : k => merge(v, {
    name = "${var.name_prefix}${v.name}"
    network_security_groups = { for kv, vv in v.network_security_groups : kv => merge(vv, {
      name = "${var.name_prefix}${vv.name}" })
    }
    route_tables = { for kv, vv in v.route_tables : kv => merge(vv, {
      name = "${var.name_prefix}${vv.name}" })
    }
  }) }
  authentication = local.test_vm_authentication[each.key]
  spoke_vms = { for k, v in each.value.spoke_vms : k => merge(v, {
    name           = "${var.name_prefix}${v.name}"
    interface_name = "${var.name_prefix}${coalesce(v.interface_name, "${v.name}-nic")}"
    disk_name      = "${var.name_prefix}${coalesce(v.disk_name, "${v.name}-osdisk")}"
  }) }
  bastions = { for k, v in each.value.bastions : k => merge(v, {
    name           = "${var.name_prefix}${v.name}"
    public_ip_name = v.public_ip_key != null ? null : "${var.name_prefix}${coalesce(v.public_ip_name, "${v.name}-pip")}"
  }) }

  tags = var.tags

}