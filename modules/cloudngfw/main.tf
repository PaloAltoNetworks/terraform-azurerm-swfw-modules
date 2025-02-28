# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_network_virtual_appliance
resource "azurerm_palo_alto_virtual_network_appliance" "this" {
  count          = var.attachment_type == "vwan" ? 1 : 0
  name           = var.palo_alto_virtual_appliance_name
  virtual_hub_id = var.virtual_hub_id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  count = !var.cngfw_config.create_public_ip && var.public_ip_ids == null ? 1 : 0

  name                = var.cngfw_config.public_ip_name
  resource_group_name = coalesce(var.cngfw_config.public_ip_resource_group_name, var.resource_group_name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  count = var.cngfw_config.create_public_ip && var.public_ip_ids == null ? 1 : 0

  name                = var.cngfw_config.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.region

  sku               = "Standard"
  allocation_method = "Static"
  tags              = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_vhub_panorama
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "this" {
  count = var.attachment_type == "vwan" && var.management_mode == "panorama" ? 1 : 0

  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.region
  panorama_base64_config = var.cngfw_config.panorama_base64_config

  plan_id              = var.plan_id
  marketplace_offer_id = var.marketplace_offer_id

  network_profile {
    public_ip_address_ids = (var.public_ip_ids != null ? values(var.public_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    egress_nat_ip_address_ids = (var.egress_nat_ip_ids != null ? values(var.egress_nat_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    virtual_hub_id               = var.virtual_hub_id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.this[0].id
  }

  dynamic "destination_nat" {
    for_each = var.cngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = (var.public_ip_ids != null ? destination_nat.value.frontend_public_ip_address_id :
        (var.cngfw_config.create_public_ip ? azurerm_public_ip.this[0].id : data.azurerm_public_ip.this[0].id))
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_virtual_network_panorama
resource "azurerm_palo_alto_next_generation_firewall_virtual_network_panorama" "this" {
  count = var.attachment_type == "vnet" && var.management_mode == "panorama" ? 1 : 0

  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.region
  panorama_base64_config = var.cngfw_config.panorama_base64_config

  plan_id              = var.plan_id
  marketplace_offer_id = var.marketplace_offer_id

  network_profile {
    public_ip_address_ids = (var.public_ip_ids != null ? values(var.public_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    egress_nat_ip_address_ids = (var.egress_nat_ip_ids != null ? values(var.egress_nat_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    vnet_configuration {
      virtual_network_id  = var.virtual_network_id
      trusted_subnet_id   = var.trusted_subnet_id
      untrusted_subnet_id = var.untrusted_subnet_id
    }
  }

  dynamic "destination_nat" {
    for_each = var.cngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = (var.public_ip_ids != null ? destination_nat.value.frontend_public_ip_address_id :
        (var.cngfw_config.create_public_ip ? azurerm_public_ip.this[0].id : data.azurerm_public_ip.this[0].id))
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_vhub_local_rulestack
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_local_rulestack" "this" {
  count = var.attachment_type == "vwan" && var.management_mode == "rulestack" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  rulestack_id        = var.cngfw_config.rulestack_id

  plan_id              = var.plan_id
  marketplace_offer_id = var.marketplace_offer_id

  network_profile {
    public_ip_address_ids = (var.public_ip_ids != null ? values(var.public_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    egress_nat_ip_address_ids = (var.egress_nat_ip_ids != null ? values(var.egress_nat_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    virtual_hub_id               = var.virtual_hub_id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.this[0].id
  }

  dynamic "destination_nat" {
    for_each = var.cngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = (var.public_ip_ids != null ? destination_nat.value.frontend_public_ip_address_id :
        (var.cngfw_config.create_public_ip ? azurerm_public_ip.this[0].id : data.azurerm_public_ip.this[0].id))
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
  tags = var.tags

}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/palo_alto_next_generation_firewall_virtual_network_local_rulestack
resource "azurerm_palo_alto_next_generation_firewall_virtual_network_local_rulestack" "this" {
  count = var.attachment_type == "vnet" && var.management_mode == "rulestack" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  rulestack_id        = var.cngfw_config.rulestack_id

  plan_id              = var.plan_id
  marketplace_offer_id = var.marketplace_offer_id


  network_profile {
    public_ip_address_ids = (var.public_ip_ids != null ? values(var.public_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    egress_nat_ip_address_ids = (var.egress_nat_ip_ids != null ? values(var.egress_nat_ip_ids) :
      (var.cngfw_config.create_public_ip ? [azurerm_public_ip.this[0].id] : (can(data.azurerm_public_ip.this[0].id) ?
    [data.azurerm_public_ip.this[0].id] : [])))
    vnet_configuration {
      virtual_network_id  = var.virtual_network_id
      trusted_subnet_id   = var.trusted_subnet_id
      untrusted_subnet_id = var.untrusted_subnet_id
    }
  }

  dynamic "destination_nat" {
    for_each = var.cngfw_config.destination_nats
    content {
      name     = destination_nat.value.destination_nat_name
      protocol = destination_nat.value.destination_nat_protocol
      frontend_config {
        port = destination_nat.value.frontend_port
        public_ip_address_id = (var.public_ip_ids != null ? destination_nat.value.frontend_public_ip_address_id :
        (var.cngfw_config.create_public_ip ? azurerm_public_ip.this[0].id : data.azurerm_public_ip.this[0].id))
      }
      backend_config {
        port              = destination_nat.value.backend_port
        public_ip_address = destination_nat.value.backend_ip_address
      }
    }
  }
  tags = var.tags
}

