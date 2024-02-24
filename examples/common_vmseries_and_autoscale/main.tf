# Generate a random password.
resource "random_password" "this" {
  count = anytrue([
    for _, v in var.scale_sets : v.authentication.password == null
    if !v.authentication.disable_password_authentication
  ]) ? 1 : 0

  length           = 16
  min_lower        = 16 - 4
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}

locals {
  authentication = {
    for k, v in var.scale_sets : k =>
    merge(
      v.authentication,
      {
        ssh_keys = [for ssh_key in v.authentication.ssh_keys : file(ssh_key)]
        password = try(coalesce(v.authentication.password, random_password.this[0].result), null)
      }
    )
  }
}

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

module "natgw" {
  source = "../../modules/natgw"

  for_each = var.natgws

  name                = each.value.natgw.create ? "${var.name_prefix}${each.value.name}" : each.value.name
  resource_group_name = coalesce(each.value.resource_group_name, local.resource_group.name)
  location            = var.location

  natgw = each.value.natgw

  subnet_ids = { for v in each.value.subnet_keys : v => module.vnet[each.value.vnet_key].subnet_ids[v] }

  public_ip        = try(merge(each.value.public_ip, { name = "${each.value.public_ip.create ? var.name_prefix : ""}${each.value.public_ip.name}" }), null)
  public_ip_prefix = try(merge(each.value.public_ip_prefix, { name = "${each.value.public_ip_prefix.create ? var.name_prefix : ""}${each.value.public_ip_prefix.name}" }), null)

  tags       = var.tags
  depends_on = [module.vnet]
}

# create load balancers, both internal and external
module "load_balancer" {
  source = "../../modules/loadbalancer"

  for_each = var.load_balancers

  name                = "${var.name_prefix}${each.value.name}"
  location            = var.location
  resource_group_name = local.resource_group.name
  load_balancer       = each.value.load_balancer

  health_probes = each.value.health_probes

  nsg_auto_rules_settings = try(
    {
      nsg_name = try(
        "${var.name_prefix}${var.vnets[each.value.nsg_auto_rules_settings.nsg_vnet_key].network_security_groups[each.value.nsg_auto_rules_settings.nsg_key].name}",
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
        public_ip_name = v.create_public_ip ? "${var.name_prefix}${v.public_ip_name}" : "${v.public_ip_name}",
        subnet_id      = try(module.vnet[each.value.vnet_key].subnet_ids[v.subnet_key], null)
      }
    )
  }

  tags       = var.tags
  depends_on = [module.vnet]
}

module "ngfw_metrics" {
  source = "../../modules/ngfw_metrics"

  count = var.ngfw_metrics != null ? 1 : 0

  create_workspace = var.ngfw_metrics.create_workspace

  name                = "${var.ngfw_metrics.create_workspace ? var.name_prefix : ""}${var.ngfw_metrics.name}"
  resource_group_name = var.ngfw_metrics.create_workspace ? local.resource_group.name : coalesce(var.ngfw_metrics.resource_group_name, local.resource_group.name)
  location            = var.location

  log_analytics_workspace = {
    sku                       = var.ngfw_metrics.sku
    metrics_retention_in_days = var.ngfw_metrics.metrics_retention_in_days
  }

  application_insights = {
    for k, v in var.scale_sets :
    k => { name = "${var.name_prefix}${v.name}-ai" }
    if length(v.autoscaling_profiles) > 0
  }

  tags = var.tags
}

module "appgw" {
  source = "../../modules/appgw"

  for_each = var.appgws

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = local.resource_group.name
  location            = var.location

  subnet_id = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]

  application_gateway = merge(
    each.value.application_gateway,
    {
      public_ip = merge(
        each.value.application_gateway.public_ip,
        { name = "${each.value.application_gateway.public_ip.create ? var.name_prefix : ""}${each.value.application_gateway.public_ip.name}" }
      )
    }
  )

  listeners        = each.value.listeners
  backend_settings = each.value.backend_settings
  probes           = each.value.probes
  rewrites         = each.value.rewrites
  rules            = each.value.rules
  redirects        = each.value.redirects
  url_path_maps    = each.value.url_path_maps
  ssl_profiles     = each.value.ssl_profiles

  tags       = var.tags
  depends_on = [module.vnet]
}

module "vmss" {
  source = "../../modules/vmss"

  for_each = var.scale_sets

  name                = "${var.name_prefix}${each.value.name}"
  resource_group_name = local.resource_group.name
  location            = var.location

  authentication            = local.authentication[each.key]
  virtual_machine_scale_set = each.value.virtual_machine_scale_set
  image                     = each.value.image

  interfaces = [
    for v in each.value.interfaces : {
      name                   = v.name
      subnet_id              = module.vnet[each.value.vnet_key].subnet_ids[v.subnet_key]
      create_public_ip       = v.create_public_ip
      pip_domain_name_label  = v.pip_domain_name_label
      lb_backend_pool_ids    = try([module.load_balancer[v.load_balancer_key].backend_pool_id], [])
      appgw_backend_pool_ids = try([module.appgw[v.application_gateway_key].backend_pool_id], [])
    }
  ]

  autoscaling_configuration = merge(
    each.value.autoscaling_configuration,
    { application_insights_id = try(module.ngfw_metrics[0].application_insights_ids[each.key], null) }
  )
  autoscaling_profiles = each.value.autoscaling_profiles

  tags       = var.tags
  depends_on = [module.vnet, module.load_balancer, module.appgw]
}
