# Generate a random password

# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "this" {
  count = anytrue([for _, v in var.vmseries : v.authentication.password == null]) ? (
    anytrue([for _, v in var.test_infrastructure : v.authentication.password == null]) ? 2 : 1
  ) : 0

  length           = 16
  min_lower        = 16 - 4
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}

locals {
  authentication = {
    for k, v in var.vmseries : k =>
    merge(
      v.authentication,
      {
        ssh_keys = [for ssh_key in v.authentication.ssh_keys : file(ssh_key)]
        password = coalesce(v.authentication.password, try(random_password.this[0].result, null))
      }
    )
  }
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

# Manage the network required for the topology

module "vnet" {
  source = "../../modules/vnet"

  for_each = var.vnets

  name                   = each.value.create_virtual_network ? "${var.name_prefix}${each.value.name}" : each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = coalesce(each.value.resource_group_name, local.resource_group.name)
  region                 = var.region

  address_space          = each.value.address_space
  enable_vnet_encryption = each.value.enable_vnet_encryption

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

# Create Gateway Load Balancers

module "gwlb" {
  for_each = var.gateway_load_balancers
  source   = "../../modules/gwlb"

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = try(each.value.resource_group_name, local.resource_group.name)
  region              = var.region

  backends     = try(each.value.backends, null)
  health_probe = try(each.value.health_probe, null)
  lb_rule      = try(each.value.lb_rule, null)

  zones = try(each.value.zones, null)
  frontend_ip = {
    name                       = coalesce(each.value.frontend_ip.name, "${var.name_prefix}${each.value.name}")
    private_ip_address_version = try(each.value.frontend_ip.private_ip_address_version, null)
    private_ip_address         = try(each.value.frontend_ip.private_ip_address, null)
    subnet_id                  = module.vnet[each.value.frontend_ip.vnet_key].subnet_ids[each.value.frontend_ip.subnet_key]
  }

  tags = var.tags
}

# Create VM-Series VMs and closely associated resources

module "ngfw_metrics" {
  source = "../../modules/ngfw_metrics"

  count = var.ngfw_metrics != null ? 1 : 0

  create_workspace = var.ngfw_metrics.create_workspace

  name = "${var.ngfw_metrics.create_workspace ? var.name_prefix : ""}${var.ngfw_metrics.name}"
  resource_group_name = var.ngfw_metrics.create_workspace ? local.resource_group.name : (
    coalesce(var.ngfw_metrics.resource_group_name, local.resource_group.name)
  )
  region = var.region

  log_analytics_workspace = {
    sku                       = var.ngfw_metrics.sku
    metrics_retention_in_days = var.ngfw_metrics.metrics_retention_in_days
  }

  application_insights = { for k, v in var.vmseries : k => { name = "${var.name_prefix}${v.name}-ai" } }

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "bootstrap_xml" {
  for_each = {
    for k, v in var.vmseries :
    k => v if try(v.virtual_machine.bootstrap_package.bootstrap_xml_template != null, false)
  }

  filename = "files/${each.key}-bootstrap.xml"
  content = templatefile(
    each.value.virtual_machine.bootstrap_package.bootstrap_xml_template,
    {
      data_gateway_ip = cidrhost(
        module.vnet[each.value.vnet_key].subnet_cidrs[each.value.virtual_machine.bootstrap_package.data_snet_key],
        1
      )

      ai_instr_key = try(
        module.ngfw_metrics[0].metrics_instrumentation_keys[each.key],
        null
      )

      ai_update_interval = each.value.virtual_machine.bootstrap_package.ai_update_interval
    }
  )

  depends_on = [
    module.ngfw_metrics,
    module.vnet
  ]
}

locals {
  bootstrap_file_shares_flat = flatten([
    for k, v in var.vmseries :
    merge(v.virtual_machine.bootstrap_package, { vm_key = k })
    if v.virtual_machine.bootstrap_package != null
  ])

  bootstrap_file_shares = { for k, v in var.bootstrap_storages : k => {
    for file_share in local.bootstrap_file_shares_flat : file_share.vm_key => {
      name                   = file_share.vm_key
      bootstrap_package_path = file_share.bootstrap_package_path
      bootstrap_files = merge(
        file_share.static_files,
        file_share.bootstrap_xml_template == null ? {} : {
          "files/${file_share.vm_key}-bootstrap.xml" = "config/bootstrap.xml"
        }
      )
      bootstrap_files_md5 = file_share.bootstrap_xml_template == null ? {} : {
        "files/${file_share.vm_key}-bootstrap.xml" = local_file.bootstrap_xml[file_share.vm_key].content_md5
      }
    } if file_share.bootstrap_storage_key == k }
  }
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  for_each = var.bootstrap_storages

  storage_account     = each.value.storage_account
  name                = each.value.name
  resource_group_name = coalesce(each.value.resource_group_name, local.resource_group.name)
  region              = var.region

  storage_network_security = merge(
    each.value.storage_network_security,
    each.value.storage_network_security.vnet_key == null ? {} : {
      allowed_subnet_ids = [
        for v in each.value.storage_network_security.allowed_subnet_keys :
        module.vnet[each.value.storage_network_security.vnet_key].subnet_ids[v]
    ] }
  )
  file_shares_configuration = each.value.file_shares_configuration
  file_shares               = local.bootstrap_file_shares[each.key]

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/availability_set
resource "azurerm_availability_set" "this" {
  for_each = var.availability_sets

  name                         = "${var.name_prefix}${each.value.name}"
  resource_group_name          = local.resource_group.name
  location                     = var.region
  platform_update_domain_count = each.value.update_domain_count
  platform_fault_domain_count  = each.value.fault_domain_count

  tags = var.tags
}

module "vmseries" {
  source = "../../modules/vmseries"

  for_each = var.vmseries

  name                = "${var.name_prefix}${each.value.name}"
  region              = var.region
  resource_group_name = local.resource_group.name

  authentication = local.authentication[each.key]
  image          = each.value.image
  virtual_machine = merge(
    each.value.virtual_machine,
    {
      disk_name = "${var.name_prefix}${coalesce(each.value.virtual_machine.disk_name, "${each.value.name}-osdisk")}"
      avset_id  = try(azurerm_availability_set.this[each.value.virtual_machine.avset_key].id, null)
      bootstrap_options = try(
        coalesce(
          each.value.virtual_machine.bootstrap_options,
          try(
            join(",", [
              "storage-account=${module.bootstrap[
              each.value.virtual_machine.bootstrap_package.bootstrap_storage_key].storage_account_name}",
              "access-key=${module.bootstrap[
              each.value.virtual_machine.bootstrap_package.bootstrap_storage_key].storage_account_primary_access_key}",
              "file-share=${each.key}",
              "share-directory=None"
            ]),
          null),
        ),
        null
      )
    }
  )

  interfaces = [for v in each.value.interfaces : {
    name             = "${var.name_prefix}${v.name}"
    subnet_id        = module.vnet[each.value.vnet_key].subnet_ids[v.subnet_key]
    create_public_ip = v.create_public_ip
    public_ip_name = v.create_public_ip ? "${var.name_prefix}${
      coalesce(v.public_ip_name, "${v.name}-pip")
    }" : v.public_ip_name
    public_ip_resource_group_name = v.public_ip_resource_group_name
    private_ip_address            = v.private_ip_address
    attach_to_lb_backend_pool     = v.load_balancer_key != null || v.gwlb_key != null
    lb_backend_pool_id            = try(module.gwlb[v.gwlb_key].backend_pool_ids[v.gwlb_backend_key], null)
  }]

  tags = var.tags
  depends_on = [
    module.vnet,
    azurerm_availability_set.this,
    module.bootstrap,
  ]
}

# Create test infrastructure

locals {
  test_vm_authentication = {
    for k, v in var.test_infrastructure : k =>
    merge(
      v.authentication,
      {
        password = coalesce(v.authentication.password, try(random_password.this[1].result, null))
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
  }) }
  load_balancers = { for k, v in each.value.load_balancers : k => merge(v, {
    name         = "${var.name_prefix}${v.name}"
    backend_name = coalesce(v.backend_name, "${v.name}-backend")
    frontend_ips = { for kv, vv in v.frontend_ips : kv => merge(vv, {
      gwlb_fip_id = try(module.gwlb[vv.gwlb_key].frontend_ip_config_id, null)
    }) }
  }) }
  authentication = local.test_vm_authentication[each.key]
  spoke_vms = { for k, v in each.value.spoke_vms : k => merge(v, {
    name           = "${var.name_prefix}${v.name}"
    interface_name = "${var.name_prefix}${coalesce(v.interface_name, "${v.name}-nic")}"
    disk_name      = "${var.name_prefix}${coalesce(v.disk_name, "${v.name}-osdisk")}"
  }) }
  bastions = { for k, v in each.value.bastions : k => merge(v, {
    name           = "${var.name_prefix}${v.name}"
    public_ip_name = "${var.name_prefix}${coalesce(v.public_ip_name, "${v.name}-pip")}"
  }) }

  tags       = var.tags
  depends_on = [module.vnet]
}
