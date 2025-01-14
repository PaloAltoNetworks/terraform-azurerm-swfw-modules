# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
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

# https://registry.terraform.io/modules/PaloAltoNetworks/swfw-modules/azurerm/latest/submodules/vnet
module "vnet" {
  source = "../vnet"

  for_each = var.vnets

  name                   = each.value.name
  create_virtual_network = each.value.create_virtual_network
  resource_group_name    = local.resource_group.name
  region                 = var.region

  address_space           = each.value.address_space
  dns_servers             = each.value.dns_servers
  vnet_encryption         = each.value.vnet_encryption
  ddos_protection_plan_id = each.value.ddos_protection_plan_id

  subnets = each.value.subnets

  network_security_groups = each.value.network_security_groups
  route_tables            = each.value.route_tables

  tags = var.tags
}

# https://registry.terraform.io/modules/PaloAltoNetworks/swfw-modules/azurerm/latest/submodules/vnet_peering
module "vnet_peering" {
  source = "../vnet_peering"

  for_each = { for k, v in var.vnets : k => v if v.hub_vnet_name != null }

  local_peer_config = {
    name                         = "peer-${each.value.name}-to-${each.value.hub_vnet_name}"
    resource_group_name          = local.resource_group.name
    vnet_name                    = each.value.name
    allow_virtual_network_access = each.value.local_peer_config.allow_virtual_network_access
    allow_forwarded_traffic      = each.value.local_peer_config.allow_forwarded_traffic
    allow_gateway_transit        = each.value.local_peer_config.allow_gateway_transit
    use_remote_gateways          = each.value.local_peer_config.use_remote_gateways
  }
  remote_peer_config = {
    name                         = "peer-${each.value.hub_vnet_name}-to-${each.value.name}"
    resource_group_name          = try(each.value.hub_resource_group_name, local.resource_group.name)
    vnet_name                    = each.value.hub_vnet_name
    allow_virtual_network_access = each.value.remote_peer_config.allow_virtual_network_access
    allow_forwarded_traffic      = each.value.remote_peer_config.allow_forwarded_traffic
    allow_gateway_transit        = each.value.remote_peer_config.allow_gateway_transit
    use_remote_gateways          = each.value.remote_peer_config.use_remote_gateways
  }

  depends_on = [module.vnet]
}

# https://registry.terraform.io/modules/PaloAltoNetworks/swfw-modules/azurerm/latest/submodules/loadbalancer
module "load_balancer" {
  source = "../loadbalancer"

  for_each = var.load_balancers

  name                = each.value.name
  region              = var.region
  resource_group_name = local.resource_group.name
  zones               = each.value.zones
  backend_name        = each.value.backend_name

  health_probes = each.value.health_probes

  nsg_auto_rules_settings = try(
    {
      nsg_name = try(
        var.vnets[each.value.nsg_auto_rules_settings.nsg_vnet_key].network_security_groups[
        each.value.nsg_auto_rules_settings.nsg_key].name,
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
        public_ip_name = v.create_public_ip ? v.public_ip_name : null
        subnet_id      = try(module.vnet[v.vnet_key].subnet_ids[v.subnet_key], null)
        gwlb_fip_id    = try(v.gwlb_fip_id, null)
      }
    )
  }

  tags       = var.tags
  depends_on = [module.vnet]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "vm" {
  for_each = var.spoke_vms

  name                = each.value.interface_name
  location            = var.region
  resource_group_name = local.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]
    private_ip_address_allocation = each.value.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = each.value.private_ip_address
  }
}

locals {
  password = sensitive(var.authentication.password)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "this" {
  for_each = var.spoke_vms

  # checkov:skip=CKV_AZURE_178:This is a test, non-production VM
  # checkov:skip=CKV_AZURE_149:This is a test, non-production VM

  name                            = each.value.name
  resource_group_name             = local.resource_group.name
  location                        = var.region
  size                            = each.value.size
  admin_username                  = var.authentication.username
  admin_password                  = local.password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.vm[each.key].id]
  allow_extension_operations      = false
  custom_data                     = each.value.custom_data

  os_disk {
    name                 = each.value.disk_name
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = each.value.image.publisher
    offer     = each.value.image.offer
    sku       = each.value.image.sku
    version   = each.value.image.version
  }

  dynamic "plan" {
    for_each = each.value.image.enable_marketplace_plan ? [1] : []
    content {
      name      = each.value.image.sku
      product   = each.value.image.offer
      publisher = each.value.image.publisher
    }
  }

  lifecycle {
    ignore_changes = [source_image_reference["version"]]
  }

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = { for k, v in var.spoke_vms : k => v if v.load_balancer_key != null }

  backend_address_pool_id = module.load_balancer[each.value.load_balancer_key].backend_pool_id
  ip_configuration_name   = azurerm_network_interface.vm[each.key].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.vm[each.key].id

  depends_on = [
    module.load_balancer,
    azurerm_network_interface.vm,
    azurerm_linux_virtual_machine.this
  ]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "bastion" {
  for_each = { for k, v in var.bastions : k => v if v.create_public_ip }

  name                = each.value.public_ip_name
  location            = var.region
  resource_group_name = local.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "bastion" {
  for_each = { for k, v in var.bastions : k => v if !v.create_public_ip && v.public_ip_name != null }

  name                = each.value.public_ip_name
  resource_group_name = coalesce(each.value.public_ip_resource_group_name, local.resource_group.name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host
resource "azurerm_bastion_host" "this" {
  for_each = var.bastions

  name                = each.value.name
  location            = var.region
  resource_group_name = local.resource_group.name

  ip_configuration {
    name      = "bastion-ip-config"
    subnet_id = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]
    public_ip_address_id = coalesce(
      each.value.public_ip_id,
      try(azurerm_public_ip.bastion[each.key].id, data.azurerm_public_ip.bastion[each.key].id, null)
    )
  }
}
