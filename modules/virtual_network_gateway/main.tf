# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  for_each = { for k, v in var.ip_configurations : k => v if try(v.create_public_ip, false) }

  resource_group_name = var.resource_group_name
  location            = var.region
  name                = each.value.public_ip_name

  allocation_method = "Static"
  sku               = "Standard"
  zones             = var.zones

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  for_each = { for k, v in var.ip_configurations : k => v
  if !try(v.create_public_ip, false) && try(v.public_ip_name, null) != null }

  name                = each.value.public_ip_name
  resource_group_name = coalesce(each.value.public_ip_resource_group_name, var.resource_group_name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway
resource "azurerm_virtual_network_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region

  type                             = var.instance_settings.type
  vpn_type                         = var.instance_settings.vpn_type
  sku                              = var.instance_settings.sku
  generation                       = var.instance_settings.type == "Vpn" ? var.instance_settings.generation : null
  active_active                    = var.instance_settings.active_active
  default_local_network_gateway_id = var.default_local_network_gateway_id
  edge_zone                        = var.edge_zone
  private_ip_address_enabled       = var.private_ip_address_enabled

  dynamic "ip_configuration" {
    for_each = [for _, v in var.ip_configurations : v if v != null]

    content {
      name = ip_configuration.value.name
      public_ip_address_id = coalesce(
        ip_configuration.value.public_ip_id,
        try(azurerm_public_ip.this[ip_configuration.value.name].id, data.azurerm_public_ip.this[ip_configuration.value.name].id, null)
      )
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      subnet_id                     = var.subnet_id
    }
  }

  enable_bgp = try(var.bgp.enable, false)

  dynamic "bgp_settings" {
    for_each = try(var.bgp.enable, false) ? [1] : []
    content {
      asn = var.bgp.configuration.asn

      peering_addresses {
        ip_configuration_name = var.bgp.configuration.primary_peering_addresses.name
        apipa_addresses = try(
          [for i in var.bgp.configuration.primary_peering_addresses.apipa_address_keys : var.azure_bgp_peer_addresses[i]],
          null
        )
        default_addresses = var.bgp.configuration.primary_peering_addresses.default_addresses
      }

      dynamic "peering_addresses" {
        for_each = var.bgp.configuration.secondary_peering_addresses != null ? [1] : []
        content {
          ip_configuration_name = var.bgp.configuration.secondary_peering_addresses.name
          apipa_addresses = try(
            [for i in var.bgp.configuration.secondary_peering_addresses.apipa_address_keys : var.azure_bgp_peer_addresses[i]],
            null
          )
          default_addresses = var.bgp.configuration.secondary_peering_addresses.default_addresses
        }
      }

      peer_weight = var.bgp.configuration.peer_weight
    }
  }

  dynamic "custom_route" {
    for_each = try(var.vpn_clients.custom_routes, false) ? [1] : []
    content {
      address_prefixes = custom_route.value
    }
  }

  dynamic "vpn_client_configuration" {
    for_each = var.vpn_clients

    content {
      address_space = vpn_client_configuration.value.address_space
      aad_tenant    = vpn_client_configuration.value.aad_tenant
      aad_audience  = vpn_client_configuration.value.aad_audience
      aad_issuer    = vpn_client_configuration.value.aad_issuer

      dynamic "root_certificate" {
        for_each = vpn_client_configuration.value.root_certificates
        content {
          name             = root_certificate.key
          public_cert_data = root_certificate.value
        }
      }

      dynamic "revoked_certificate" {
        for_each = vpn_client_configuration.value.revoked_certificates
        content {
          name       = revoked_certificate.key
          thumbprint = revoked_certificate.value
        }
      }

      radius_server_address = vpn_client_configuration.value.radius_server_address
      radius_server_secret  = vpn_client_configuration.value.radius_server_secret
      vpn_client_protocols  = vpn_client_configuration.value.vpn_client_protocols
      vpn_auth_types        = vpn_client_configuration.value.vpn_auth_types
    }
  }

  tags = var.tags

  lifecycle {
    precondition { # bgp
      condition     = var.instance_settings.type == "ExpressRoute" ? var.bgp == null : true
      error_message = <<-EOF
      VNG Name: [${var.name}]
      BGP configuration is supported only for Virtual Network Gateways of "VPN" type, `var.bgp` should have a value of `null`.
      EOF
    }
    precondition { # azure_bgp_peer_addresses
      condition     = var.instance_settings.type == "ExpressRoute" ? length(var.azure_bgp_peer_addresses) == 0 : true
      error_message = <<-EOF
      VNG Name: [${var.name}]
      BGP configuration is supported only for Virtual Network Gateways of "VPN" type, `var.azure_bgp_peer_addresses` map should
      be empty.
      EOF
    }
    precondition { # ip_configurations.secondary
      condition = var.instance_settings.active_active ? (
        var.ip_configurations.secondary != null
      ) : var.ip_configurations.secondary == null
      error_message = <<-EOF
      VNG Name: [${var.name}]
      The `ip_configurations.secondary` property is required ONLY when `instance_settings.active_active` property is set
      to `true`.
      EOF
    }
    precondition { # bgp.configuration.secondary_peering_addresses
      condition = var.instance_settings.active_active ? (
        var.bgp.configuration.secondary_peering_addresses != null
      ) : try(var.bgp.configuration.secondary_peering_addresses, null) == null
      error_message = <<-EOF
      VNG Name: [${var.name}]
      The `bgp.configuration.secondary_peering_addresses` property is required ONLY when `instance_settings.active_active`
      property is set to `true`.
      EOF
    }
    precondition { # zones
      condition = var.instance_settings.type == "Vpn" && can(
        regex("^\\w{5,6}$", var.instance_settings.sku)
      ) ? length(coalesce(var.zones, [])) == 0 : true
      error_message = <<-EOF
      For Virtual Network Gateways of `Vpn` type, sku of non `AZ` type, the `zones` variable has to be an empty list.
      EOF
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway 
resource "azurerm_local_network_gateway" "this" {
  for_each = var.local_network_gateways

  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.region
  gateway_address     = each.value.gateway_address
  address_space       = each.value.address_space


  dynamic "bgp_settings" {
    for_each = each.value.remote_bgp_settings != null ? [1] : []
    content {
      asn                 = each.value.remote_bgp_settings.asn
      bgp_peering_address = each.value.remote_bgp_settings.bgp_peering_address
      peer_weight         = each.value.remote_bgp_settings.peer_weight
    }
  }

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection
resource "azurerm_virtual_network_gateway_connection" "this" {
  for_each = var.local_network_gateways

  name                = each.value.connection.name
  location            = var.region
  resource_group_name = var.resource_group_name

  type                       = each.value.connection.type
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.this[each.key].id

  enable_bgp                     = var.bgp.enable
  local_azure_ip_address_enabled = var.private_ip_address_enabled
  shared_key                     = each.value.connection.shared_key

  dynamic "custom_bgp_addresses" {
    for_each = each.value.connection.custom_bgp_addresses != null ? [1] : []
    content {
      primary   = var.azure_bgp_peer_addresses[each.value.connection.custom_bgp_addresses.primary_key]
      secondary = try(var.azure_bgp_peer_addresses[each.value.connection.custom_bgp_addresses.secondary_key], null)
    }
  }

  connection_mode = each.value.connection.mode
  dynamic "ipsec_policy" {
    for_each = each.value.connection.ipsec_policies
    content {
      dh_group         = ipsec_policy.value.dh_group
      ike_encryption   = ipsec_policy.value.ike_encryption
      ike_integrity    = ipsec_policy.value.ike_integrity
      ipsec_encryption = ipsec_policy.value.ipsec_encryption
      ipsec_integrity  = ipsec_policy.value.ipsec_integrity
      pfs_group        = ipsec_policy.value.pfs_group
      sa_datasize      = ipsec_policy.value.sa_datasize
      sa_lifetime      = ipsec_policy.value.sa_lifetime
    }
  }

  tags = var.tags
}
