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

# Create or source a Network resources

module "vnet" {
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = each.value.create_virtual_network ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                 = var.region

  address_space   = each.value.address_space
  dns_servers     = each.value.dns_servers
  vnet_encryption = each.value.vnet_encryption

  subnets = each.value.subnets

  network_security_groups = {
    for k, v in each.value.network_security_groups : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }
  route_tables = {
    for k, v in each.value.route_tables : k => merge(v, { name = "${var.name_prefix}${v.name}" })
  }

  tags = var.tags
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

# Create a CNGFWs

module "cngfw" {
  source = "../../modules/cloudngfw"

  for_each = var.cngfws

  name            = each.value.name
  attachment_type = each.value.attachment_type
  management_mode = each.value.management_mode
  cngfw_config = merge(each.value.cngfw_config, {
    destination_nats = {
      for k, v in each.value.cngfw_config.destination_nats : k => merge(v, {
        frontend_public_ip_address_id = v.frontend_public_ip_key != null ? lookup(module.public_ip.pip_ids, v.frontend_public_ip_key, null) : null
      })
    }
  })
  public_ip_ids       = module.public_ip.pip_ids
  egress_nat_ip_ids   = module.public_ip.pip_ids
  resource_group_name = local.resource_group.name
  region              = var.region
  virtual_network_id  = each.value.attachment_type == "vnet" ? module.vnet[each.value.virtual_network_key].virtual_network_id : null
  trusted_subnet_id   = each.value.attachment_type == "vnet" ? module.vnet[each.value.virtual_network_key].subnet_ids[each.value.trusted_subnet_key] : null
  untrusted_subnet_id = each.value.attachment_type == "vnet" ? module.vnet[each.value.virtual_network_key].subnet_ids[each.value.untrusted_subnet_key] : null
  tags                = var.tags
}


module "vnet_peering" {
  source = "../../modules/vnet_peering"

  for_each = var.vnet_peerings

  local_peer_config = {
    name                = "peer-${each.value.local_vnet_name}-to-${each.value.remote_vnet_name}"
    resource_group_name = coalesce(each.value.local_resource_group_name, local.resource_group.name)
    vnet_name           = each.value.local_vnet_name
  }
  remote_peer_config = {
    name                = "peer-${each.value.remote_vnet_name}-to-${each.value.local_vnet_name}"
    resource_group_name = coalesce(each.value.remote_resource_group_name, local.resource_group.name)
    vnet_name           = each.value.remote_vnet_name
  }
  depends_on = [module.vnet]
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
    name                    = "${var.name_prefix}${v.name}"
    hub_vnet_name           = "${var.name_prefix}${v.hub_vnet_name}"
    hub_resource_group_name = coalesce(v.hub_resource_group_name, local.resource_group.name)
    network_security_groups = { for kv, vv in v.network_security_groups : kv => merge(vv, {
      name = "${var.name_prefix}${vv.name}" })
    }
    route_tables = { for kv, vv in v.route_tables : kv => merge(vv, {
      name = "${var.name_prefix}${vv.name}" })
    }
    local_peer_config  = try(v.local_peer_config, {})
    remote_peer_config = try(v.remote_peer_config, {})
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
  tags       = var.tags
  depends_on = [module.vnet]
}