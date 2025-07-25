# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  for_each = { for v in var.interfaces : v.name => v if v.create_public_ip }

  location            = var.region
  resource_group_name = var.resource_group_name
  name                = each.value.public_ip_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.virtual_machine.zone != null ? [var.virtual_machine.zone] : null
  tags                = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  for_each = { for v in var.interfaces : v.name => v if !v.create_public_ip && v.public_ip_name != null
  }

  name                = each.value.public_ip_name
  resource_group_name = coalesce(each.value.public_ip_resource_group_name, var.resource_group_name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "this" {
  for_each = { for k, v in var.interfaces : v.name => merge(v, { index = k }) }

  name                           = each.value.name
  location                       = var.region
  resource_group_name            = var.resource_group_name
  accelerated_networking_enabled = each.value.index == 0 ? false : var.virtual_machine.accelerated_networking
  ip_forwarding_enabled          = each.value.index == 0 ? false : true
  tags                           = var.tags

  ip_configuration {
    name                          = each.value.ip_configuration_name
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = each.value.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = each.value.private_ip_address
    public_ip_address_id = try(coalesce(
      each.value.public_ip_id,
      try(azurerm_public_ip.this[each.value.name].id, data.azurerm_public_ip.this[each.value.name].id, null)
    ), null)
  }
}

locals {
  password = sensitive(var.authentication.password)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "this" {
  name                = var.name
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  size                          = var.virtual_machine.size
  zone                          = var.virtual_machine.zone
  availability_set_id           = var.virtual_machine.avset_id
  capacity_reservation_group_id = var.virtual_machine.capacity_reservation_group_id
  allow_extension_operations    = var.virtual_machine.allow_extension_operations
  encryption_at_host_enabled    = var.virtual_machine.encryption_at_host_enabled

  network_interface_ids = [for v in var.interfaces : azurerm_network_interface.this[v.name].id]

  admin_username                  = var.authentication.username
  admin_password                  = var.authentication.disable_password_authentication ? null : local.password
  disable_password_authentication = var.authentication.disable_password_authentication

  dynamic "admin_ssh_key" {
    for_each = { for k, v in var.authentication.ssh_keys : k => v }
    content {
      username   = var.authentication.username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    name                   = var.virtual_machine.disk_name
    storage_account_type   = var.virtual_machine.disk_type
    caching                = "ReadWrite"
    disk_encryption_set_id = var.virtual_machine.disk_encryption_set_id
  }

  source_image_id = var.image.custom_id

  dynamic "source_image_reference" {
    for_each = var.image.custom_id == null ? [1] : []
    content {
      publisher = var.image.use_airs ? "paloaltonetworks" : var.image.publisher
      offer     = var.image.use_airs ? "airs-flex" : var.image.offer
      sku       = var.image.use_airs ? "airs-byol" : var.image.sku
      version   = var.image.version
    }
  }

  dynamic "plan" {
    for_each = var.image.enable_marketplace_plan ? [1] : []

    content {
      name      = var.image.use_airs ? "airs-byol" : var.image.sku
      publisher = var.image.use_airs ? "paloaltonetworks" : var.image.publisher
      product   = var.image.use_airs ? "airs-flex" : var.image.offer
    }
  }

  custom_data = var.virtual_machine.bootstrap_options == null ? null : base64encode(var.virtual_machine.bootstrap_options)

  # An empty block boot_diagnostics {} will use managed storage
  dynamic "boot_diagnostics" {
    for_each = var.virtual_machine.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = var.virtual_machine.boot_diagnostics_storage_uri
    }
  }

  identity {
    type         = var.virtual_machine.identity_type
    identity_ids = var.virtual_machine.identity_ids
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = { for v in var.interfaces : v.name => v.lb_backend_pool_id if v.attach_to_lb_backend_pool }

  backend_address_pool_id = each.value
  ip_configuration_name   = azurerm_network_interface.this[each.key].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.this[each.key].id

  depends_on = [
    azurerm_network_interface.this,
    azurerm_linux_virtual_machine.this
  ]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_application_gateway_backend_address_pool_association
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "this" {

  for_each = { for v in var.interfaces : v.name => v.appgw_backend_pool_id if v.attach_to_appgw_backend_pool }

  network_interface_id    = azurerm_network_interface.this[each.key].id
  ip_configuration_name   = azurerm_network_interface.this[each.key].ip_configuration[0].name
  backend_address_pool_id = each.value

  depends_on = [
    azurerm_network_interface.this,
    azurerm_linux_virtual_machine.this
  ]
}
