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

  address_space = each.value.address_space

  create_subnets = each.value.create_subnets
  subnets        = each.value.subnets

  network_security_groups = each.value.network_security_groups
  route_tables            = each.value.route_tables

  tags = var.tags
}

# https://registry.terraform.io/modules/PaloAltoNetworks/swfw-modules/azurerm/latest/submodules/vnet_peering
module "vnet_peering" {
  source   = "../vnet_peering"
  for_each = { for k, v in var.vnets : k => v if v.hub_vnet_name != null }


  local_peer_config = {
    name                = "peer-${each.value.name}-to-${each.value.hub_vnet_name}"
    resource_group_name = local.resource_group.name
    vnet_name           = each.value.name
  }
  remote_peer_config = {
    name                = "peer-${each.value.hub_vnet_name}-to-${each.value.name}"
    resource_group_name = try(each.value.hub_resource_group_name, local.resource_group.name)
    vnet_name           = each.value.hub_vnet_name
  }

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
    private_ip_address_allocation = "Dynamic"
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
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "bastion" {

  for_each = var.bastions

  name                = each.value.public_ip_name
  location            = var.region
  resource_group_name = local.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host
resource "azurerm_bastion_host" "this" {

  for_each = var.bastions

  name                = each.value.name
  location            = var.region
  resource_group_name = local.resource_group.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]
    public_ip_address_id = azurerm_public_ip.bastion[each.key].id
  }
}
