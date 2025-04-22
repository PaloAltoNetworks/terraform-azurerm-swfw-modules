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
    for val in { for k, v in module.test_infrastructure : k => v.vnet_ids } : [
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
  source = "../../modules/vwan"

  virtual_wan_name    = var.virtual_wan.create_virtual_wan ? "${var.name_prefix}${var.virtual_wan.name}" : var.virtual_wan.name
  resource_group_name = coalesce(var.virtual_wan.resource_group_name, local.resource_group.name)
  region              = coalesce(var.virtual_wan.region, var.region)
  tags                = var.tags
}

#VHUB
module "virtual_hub" {
  source = "../../modules/vhub"

  for_each = var.virtual_wan.virtual_hubs

  virtual_hub_name           = each.value.create_virtual_hub ? "${var.name_prefix}${each.value.name}" : each.value.name
  resource_group_name        = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                     = coalesce(each.value.region, var.region)
  virtual_hub_address_prefix = each.value.address_prefix
  virtual_wan_id             = module.virtual_wan.virtual_wan_id
  connections = {
    for k, v in each.value.connections : k => merge(v, {
      remote_virtual_network_id = v.connection_type == "Vnet" ? local.remote_virtual_network_ids[v.remote_virtual_network_key] : null
    })
  }
  tags = var.tags
}

#VIRTUAL HUB ROUTING
module "vhub_routing" {
  source = "../../modules/vhub_routing"

  for_each = var.virtual_wan.virtual_hubs

  routing_intent = merge(each.value.routing_intent, {
    routing_policy = [
      for policy in each.value.routing_intent.routing_policy : merge(policy, {
        next_hop_id = module.cloudngfw[policy.next_hop_key].palo_alto_virtual_network_appliance_id
      })
    ]
  })
  virtual_hub_id = module.virtual_hub[each.key].virtual_hub_id
}

# Create or source a Public IPs
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

# Create Cloud Next-Generation Firewalls

module "cloudngfw" {
  source = "../../modules/cloudngfw"

  for_each = var.cloudngfws

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = local.resource_group.name
  region              = var.region

  attachment_type = each.value.attachment_type
  management_mode = each.value.management_mode
  cloudngfw_config = merge(each.value.cloudngfw_config, {
    public_ip_name = each.value.cloudngfw_config.public_ip_keys == null ? (each.value.cloudngfw_config.create_public_ip ? "${
      var.name_prefix}${coalesce(each.value.cloudngfw_config.public_ip_name, "${each.value.name}-pip")
    }" : each.value.cloudngfw_config.public_ip_name) : null
    public_ip_ids = try({ for k, v in module.public_ip.pip_ids : k => v
    if contains(each.value.cloudngfw_config.public_ip_keys, k) }, null)
    egress_nat_ip_ids = try({ for k, v in module.public_ip.pip_ids : k => v
    if contains(each.value.cloudngfw_config.egress_nat_ip_keys, k) }, null)
    destination_nats = {
      for k, v in each.value.cloudngfw_config.destination_nats : k => merge(v, {
        frontend_public_ip_address_id = v.frontend_public_ip_key != null ? lookup(module.public_ip.pip_ids, v.frontend_public_ip_key, null) : null
      })
    }
  })
  virtual_hub_id = each.value.attachment_type == "vwan" ? module.virtual_hub[each.value.virtual_hub_key].virtual_hub_id : null
  tags           = var.tags
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