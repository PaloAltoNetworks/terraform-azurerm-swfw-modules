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

  address_space           = each.value.address_space
  dns_servers             = each.value.dns_servers
  vnet_encryption         = each.value.vnet_encryption
  ddos_protection_plan_id = each.value.ddos_protection_plan_id

  subnets = each.value.subnets

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

module "natgw" {
  source = "../../modules/natgw"

  for_each = var.natgws

  create_natgw        = each.value.create_natgw
  name                = each.value.create_natgw ? "${var.name_prefix}${each.value.name}" : each.value.name
  resource_group_name = coalesce(each.value.resource_group_name, local.resource_group.name)
  region              = var.region
  zone                = try(each.value.zone, null)
  idle_timeout        = each.value.idle_timeout
  subnet_ids          = { for v in each.value.subnet_keys : v => module.vnet[each.value.vnet_key].subnet_ids[v] }

  public_ip = try(merge(each.value.public_ip, {
    name = "${each.value.public_ip.create ? var.name_prefix : ""}${each.value.public_ip.name}"
    id   = try(module.public_ip.pip_ids[each.value.key], null)
  }), null)
  public_ip_prefix = try(merge(each.value.public_ip_prefix, {
    name = "${each.value.public_ip_prefix.create ? var.name_prefix : ""}${each.value.public_ip_prefix.name}"
    id   = try(module.public_ip.ippre_ids[each.value.key], null)
  }), null)

  tags       = var.tags
  depends_on = [module.vnet]
}

# Create Load Balancers, both internal and external

module "load_balancer" {
  source = "../../modules/loadbalancer"

  for_each = var.load_balancers

  name                = "${var.name_prefix}${each.value.name}"
  region              = var.region
  resource_group_name = local.resource_group.name
  zones               = each.value.zones
  backend_name        = each.value.backend_name

  health_probes = each.value.health_probes

  nsg_auto_rules_settings = try(
    {
      nsg_name = try(
        "${var.name_prefix}${var.vnets[each.value.nsg_auto_rules_settings.nsg_vnet_key].network_security_groups[
        each.value.nsg_auto_rules_settings.nsg_key].name}",
        each.value.nsg_auto_rules_settings.nsg_name
      )
      nsg_resource_group_name = try(
        var.vnets[each.value.nsg_auto_rules_settings.nsg_vnet_key].resource_group_name,
        each.value.nsg_auto_rules_settings.nsg_resource_group_name,
        null
      )
      source_ips    = each.value.nsg_auto_rules_settings.source_ips
      base_priority = each.value.nsg_auto_rules_settings.base_priority
    },
    null
  )

  frontend_ips = {
    for k, v in each.value.frontend_ips : k => merge(
      v,
      {
        public_ip_name           = v.create_public_ip ? "${var.name_prefix}${v.public_ip_name}" : v.public_ip_name,
        public_ip_id             = try(module.public_ip.pip_ids[v.public_ip_key], null)
        public_ip_address        = try(module.public_ip.pip_ip_addresses[v.public_ip_key], null)
        public_ip_prefix_id      = try(module.public_ip.ippre_ids[v.public_ip_prefix_key], null)
        public_ip_prefix_address = try(module.public_ip.ippre_ip_prefixes[v.public_ip_prefix_key], null)
        subnet_id                = try(module.vnet[each.value.vnet_key].subnet_ids[v.subnet_key], null)
      }
    )
  }

  tags       = var.tags
  depends_on = [module.vnet]
}

# Create Application Gateways

locals {
  nics_with_appgw_key = flatten([
    for k, v in var.vmseries : [
      for nic in v.interfaces : {
        vm_key    = k
        nic_name  = nic.name
        appgw_key = nic.application_gateway_key
      } if nic.application_gateway_key != null
  ]])

  ips_4_nics_with_appgw_key = {
    for v in local.nics_with_appgw_key :
    v.appgw_key => module.vmseries[v.vm_key].interfaces["${var.name_prefix}${v.nic_name}"].private_ip_address...
  }
}

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
  backend_pool = merge(
    each.value.backend_pool,
    length(local.ips_4_nics_with_appgw_key) == 0 ? {} : { vmseries_ips = local.ips_4_nics_with_appgw_key[each.key] }
  )
  backend_settings = each.value.backend_settings
  probes           = each.value.probes
  rewrites         = each.value.rewrites
  redirects        = each.value.redirects
  url_path_maps    = each.value.url_path_maps
  rules            = each.value.rules

  tags       = var.tags
  depends_on = [module.vnet, module.vmseries]
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
    for k, v in var.vmseries : k => merge(v.virtual_machine, { vnet_key = v.vnet_key })
    if try(
      v.virtual_machine.bootstrap_package.bootstrap_xml_template != null,
      var.vmseries_universal.bootstrap_package.bootstrap_xml_template != null,
      false
    )
  }

  filename = "files/${each.key}-bootstrap.xml"
  content = templatefile(
    try(each.value.bootstrap_package.bootstrap_xml_template, var.vmseries_universal.bootstrap_package.bootstrap_xml_template),
    {
      private_azure_router_ip = cidrhost(
        module.vnet[each.value.vnet_key].subnet_cidrs[
          try(each.value.bootstrap_package.private_snet_key, var.vmseries_universal.bootstrap_package.private_snet_key)
        ],
        1
      )

      public_azure_router_ip = cidrhost(
        module.vnet[each.value.vnet_key].subnet_cidrs[
          try(each.value.bootstrap_package.public_snet_key, var.vmseries_universal.bootstrap_package.public_snet_key)
        ],
        1
      )

      ai_instr_key = try(
        module.ngfw_metrics[0].metrics_instrumentation_keys[each.key],
        null
      )

      ai_update_interval = try(
        each.value.bootstrap_package.ai_update_interval, var.vmseries_universal.bootstrap_package.ai_update_interval
      )

      private_network_cidr = coalesce(
        try(each.value.bootstrap_package.intranet_cidr, var.vmseries_universal.bootstrap_package.intranet_cidr, null),
        module.vnet[each.value.vnet_key].vnet_cidr[0]
      )

      mgmt_profile_appgw_cidr = flatten([
        for _, v in var.appgws : var.vnets[v.vnet_key].subnets[v.subnet_key].address_prefixes
      ])
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
    merge(try(coalesce(v.virtual_machine.bootstrap_package, var.vmseries_universal.bootstrap_package), null), { vm_key = k })
    if try(v.virtual_machine.bootstrap_package != null || var.vmseries_universal.bootstrap_package != null, false)
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
  image = merge(
    each.value.image,
    {
      version = try(each.value.image.version, var.vmseries_universal.version, null)
    }
  )
  virtual_machine = merge(
    each.value.virtual_machine,
    {
      disk_name = "${var.name_prefix}${coalesce(each.value.virtual_machine.disk_name, "${each.value.name}-osdisk")}"
      avset_id  = try(azurerm_availability_set.this[each.value.virtual_machine.avset_key].id, null)
      size      = try(coalesce(each.value.virtual_machine.size, var.vmseries_universal.size), null)
      bootstrap_options = try(
        join(";", [for k, v in each.value.virtual_machine.bootstrap_options : "${k}=${v}" if v != null]),
        join(";", [for k, v in var.vmseries_universal.bootstrap_options : "${k}=${v}" if v != null]),
        join(";", [
          "storage-account=${module.bootstrap[
          each.value.virtual_machine.bootstrap_package.bootstrap_storage_key].storage_account_name}",
          "access-key=${module.bootstrap[
          each.value.virtual_machine.bootstrap_package.bootstrap_storage_key].storage_account_primary_access_key}",
          "file-share=${each.key}",
          "share-directory=None"
        ]),
        join(";", [
          "storage-account=${module.bootstrap[
          var.vmseries_universal.bootstrap_package.bootstrap_storage_key].storage_account_name}",
          "access-key=${module.bootstrap[
          var.vmseries_universal.bootstrap_package.bootstrap_storage_key].storage_account_primary_access_key}",
          "file-share=${each.key}",
          "share-directory=None"
        ]),
        null
      )
      bootstrap_package = try(
        coalesce(each.value.virtual_machine.bootstrap_package, var.vmseries_universal.bootstrap_package),
        null
      )
    }
  )

  interfaces = [for v in each.value.interfaces : {
    name                  = "${var.name_prefix}${v.name}"
    subnet_id             = module.vnet[each.value.vnet_key].subnet_ids[v.subnet_key]
    ip_configuration_name = v.ip_configuration_name
    create_public_ip      = v.create_public_ip
    public_ip_name = v.create_public_ip ? "${
      var.name_prefix}${coalesce(v.public_ip_name, "${v.name}-pip")
    }" : v.public_ip_name
    public_ip_resource_group_name = v.public_ip_resource_group_name
    public_ip_id                  = try(module.public_ip.pip_ids[v.public_ip_key], null)
    private_ip_address            = v.private_ip_address
    attach_to_lb_backend_pool     = v.load_balancer_key != null
    lb_backend_pool_id            = try(module.load_balancer[v.load_balancer_key].backend_pool_id, null)
    attach_to_appgw_backend_pool  = v.appgw_backend_pool_id != null
    appgw_backend_pool_id         = try(v.appgw_backend_pool_id, null)
  }]

  tags = var.tags
  depends_on = [
    module.vnet,
    azurerm_availability_set.this,
    module.load_balancer,
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
    local_peer_config  = try(v.local_peer_config, {})
    remote_peer_config = try(v.remote_peer_config, {})
  }) }
  load_balancers = { for k, v in each.value.load_balancers : k => merge(v, {
    name         = "${var.name_prefix}${v.name}"
    backend_name = coalesce(v.backend_name, "${v.name}-backend")
    public_ip_name = v.frontend_ips.create_public_ip ? (
      "${var.name_prefix}${v.frontend_ips.public_ip_name}"
    ) : v.frontend_ips.public_ip_name
    public_ip_id             = try(module.public_ip.pip_ids[v.frontend_ips.public_ip_key], null)
    public_ip_address        = try(module.public_ip.pip_ip_addresses[v.frontend_ips.public_ip_key], null)
    public_ip_prefix_id      = try(module.public_ip.ippre_ids[v.frontend_ips.public_ip_prefix_key], null)
    public_ip_prefix_address = try(module.public_ip.ippre_ip_prefixes[v.frontend_ips.public_ip_prefix_key], null)
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
    public_ip_id   = try(module.public_ip.pip_ids[v.public_ip_key], null)
  }) }

  tags       = var.tags
  depends_on = [module.vnet]
}
