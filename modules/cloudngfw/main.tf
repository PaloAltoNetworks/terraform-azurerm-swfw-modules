# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  count = var.cloudngfw_config.create_public_ip && var.cloudngfw_config.public_ip_name != null ? 1 : 0

  name                = var.cloudngfw_config.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = var.tags

  sku               = "Standard"
  allocation_method = "Static"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  count = !var.cloudngfw_config.create_public_ip && var.cloudngfw_config.public_ip_name != null ? 1 : 0

  name                = var.cloudngfw_config.public_ip_name
  resource_group_name = coalesce(var.cloudngfw_config.public_ip_resource_group_name, var.resource_group_name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_virtual_network_panorama
resource "azurerm_palo_alto_next_generation_firewall_virtual_network_panorama" "this" {
  count = var.attachment_type == "vnet" && var.management_mode == "panorama" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = var.tags

  plan_id                = var.cloudngfw_config.plan_id
  marketplace_offer_id   = var.cloudngfw_config.marketplace_offer_id
  panorama_base64_config = var.cloudngfw_config.panorama_base64_config

  network_profile {
    public_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.public_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    egress_nat_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.egress_nat_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    trusted_address_ranges = var.cloudngfw_config.trusted_address_ranges
    vnet_configuration {
      virtual_network_id  = var.virtual_network_id
      untrusted_subnet_id = var.untrusted_subnet_id
      trusted_subnet_id   = var.trusted_subnet_id
    }
  }

  dynamic "destination_nat" {
    for_each = var.cloudngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(
          try(destination_nat.value.frontend_public_ip_address_id, null),
          try(azurerm_public_ip.this[0].id, data.azurerm_public_ip.this[0].id, null)
        )
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_virtual_network_local_rulestack
resource "azurerm_palo_alto_next_generation_firewall_virtual_network_local_rulestack" "this" {
  count = var.attachment_type == "vnet" && var.management_mode == "rulestack" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  plan_id              = var.cloudngfw_config.plan_id
  marketplace_offer_id = var.cloudngfw_config.marketplace_offer_id
  rulestack_id         = var.cloudngfw_config.rulestack_id

  network_profile {
    public_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.public_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    egress_nat_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.egress_nat_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    trusted_address_ranges = var.cloudngfw_config.trusted_address_ranges
    vnet_configuration {
      virtual_network_id  = var.virtual_network_id
      untrusted_subnet_id = var.untrusted_subnet_id
      trusted_subnet_id   = var.trusted_subnet_id
    }
  }

  dynamic "destination_nat" {
    for_each = var.cloudngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(
          try(destination_nat.value.frontend_public_ip_address_id, null),
          try(azurerm_public_ip.this[0].id, data.azurerm_public_ip.this[0].id, null)
        )
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_network_virtual_appliance
resource "azurerm_palo_alto_virtual_network_appliance" "this" {
  count = var.attachment_type == "vwan" ? 1 : 0

  name           = var.name
  virtual_hub_id = var.virtual_hub_id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_vhub_panorama
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "this" {
  count = var.attachment_type == "vwan" && var.management_mode == "panorama" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = var.tags

  plan_id                = var.cloudngfw_config.plan_id
  marketplace_offer_id   = var.cloudngfw_config.marketplace_offer_id
  panorama_base64_config = var.cloudngfw_config.panorama_base64_config

  network_profile {
    public_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.public_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    egress_nat_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.egress_nat_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    trusted_address_ranges       = var.cloudngfw_config.trusted_address_ranges
    virtual_hub_id               = var.virtual_hub_id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.this[0].id
  }

  dynamic "destination_nat" {
    for_each = var.cloudngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(
          try(destination_nat.value.frontend_public_ip_address_id, null),
          try(azurerm_public_ip.this[0].id, data.azurerm_public_ip.this[0].id, null)
        )
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_vhub_local_rulestack
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack" "this" {
  count = var.attachment_type == "vwan" && var.management_mode == "rulestack" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  plan_id              = var.cloudngfw_config.plan_id
  marketplace_offer_id = var.cloudngfw_config.marketplace_offer_id
  rulestack_id         = var.cloudngfw_config.rulestack_id

  network_profile {
    public_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.public_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    egress_nat_ip_address_ids = coalesce(
      try(values(var.cloudngfw_config.egress_nat_ip_ids), null),
      try([azurerm_public_ip.this[0].id], [data.azurerm_public_ip.this[0].id], null)
    )
    trusted_address_ranges       = var.cloudngfw_config.trusted_address_ranges
    virtual_hub_id               = var.virtual_hub_id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.this[0].id
  }

  dynamic "destination_nat" {
    for_each = var.cloudngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = coalesce(
          try(destination_nat.value.frontend_public_ip_address_id, null),
          try(azurerm_public_ip.this[0].id, data.azurerm_public_ip.this[0].id, null)
        )
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
}
