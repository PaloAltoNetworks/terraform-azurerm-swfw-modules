# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  for_each = { for k, v in var.network.ip_configurations : k => v if v.create_public_ip }

  resource_group_name = var.resource_group_name
  location            = var.location
  name                = each.value.public_ip_name

  allocation_method = "Static"
  sku               = "Standard"
  zones             = var.network.public_ip_zones

  tags = var.tags

  # lifecycle {
  #   precondition {
  #     condition = var.active_active ? (
  #       var.zones != null ? length(var.zones) == 3 : false
  #     ) : true
  #     error_message = "For active-active you need to configure zones"
  #   }
  # }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "exists" {
  for_each = { for k, v in var.network.ip_configurations : k => v if !v.create_public_ip }

  name                = each.value.public_ip_name
  resource_group_name = var.resource_group_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway
resource "azurerm_virtual_network_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  type                             = var.virtual_network_gateway.type
  vpn_type                         = var.virtual_network_gateway.vpn_type
  sku                              = var.virtual_network_gateway.sku
  generation                       = var.virtual_network_gateway.generation
  active_active                    = var.virtual_network_gateway.active_active
  default_local_network_gateway_id = var.network.default_local_network_gateway_id
  edge_zone                        = var.network.edge_zone
  private_ip_address_enabled       = var.network.private_ip_address_enabled

  dynamic "ip_configuration" {
    for_each = var.network.ip_configurations

    content {
      name                          = ip_configuration.value.name
      public_ip_address_id          = ip_configuration.value.create_public_ip ? azurerm_public_ip.this[ip_configuration.value.name].id : data.azurerm_public_ip.exists[ip_configuration.value.name].id
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      subnet_id                     = var.network.subnet_id
    }
  }

  enable_bgp = var.bgp.enable

  dynamic "bgp_settings" {
    for_each = var.bgp.enable ? [1] : []
    content {
      asn = var.bgp.configuration.asn

      peering_addresses {
        ip_configuration_name = var.bgp.configuration.primary_peering_addresses.name
        apipa_addresses = [
          for i in var.bgp.configuration.primary_peering_addresses.apipa_address_keys : var.azure_bgp_peer_addresses[i]
        ]
        default_addresses = var.bgp.configuration.primary_peering_addresses.default_addresses
      }

      dynamic "peering_addresses" {
        for_each = var.bgp.configuration.secondary_peering_addresses != null ? [1] : []
        content {
          ip_configuration_name = var.bgp.configuration.secondary_peering_addresses.name
          apipa_addresses = [
            for i in var.bgp.configuration.secondary_peering_addresses.apipa_address_keys : var.azure_bgp_peer_addresses[i]
          ]
          default_addresses = var.bgp.configuration.secondary_peering_addresses.default_addresses
        }
      }

      peer_weight = var.bgp.configuration.peer_weight
    }
  }

  dynamic "custom_route" {
    for_each = var.virtual_network_gateway.custom_routes
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

  # lifecycle {
  #   precondition {
  #     condition = (contains(["VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.sku) && var.generation == "Generation2"
  #     ) || (contains(["Basic", "Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ", "VpnGw1", "VpnGw1AZ"], var.sku) && var.generation == "Generation1")
  #     error_message = "Generation2 is only value for a sku larger than VpnGw2 or VpnGw2AZ"
  #   }
  #   precondition {
  #     condition     = var.active_active && length(keys(var.local_bgp_settings.peering_addresses)) == 2 || !var.active_active && length(keys(var.local_bgp_settings.peering_addresses)) == 1
  #     error_message = "Map of peering addresses has to contain 1 (for active-standby) or 2 objects (for active-active)."
  #   }
  #   precondition {
  #     condition     = var.active_active && length(keys(var.azure_bgp_peers_addresses)) >= 2 || !var.active_active && length(keys(var.azure_bgp_peers_addresses)) >= 1
  #     error_message = "For active-standby you need to configure at least 1 custom Azure APIPA BGP IP address, for active-active at least 2."
  #   }
  # }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway 
resource "azurerm_local_network_gateway" "this" {
  for_each = var.local_network_gateways

  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  gateway_address     = each.value.gateway_address
  address_space       = each.value.address_space

  dynamic "bgp_settings" {
    for_each = each.value.remote_bgp_settings
    content {
      asn                 = bgp_settings.value.asn
      bgp_peering_address = bgp_settings.value.bgp_peering_address
      peer_weight         = bgp_settings.value.peer_weight
    }
  }

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection
resource "azurerm_virtual_network_gateway_connection" "this" {
  for_each = var.local_network_gateways

  name                = each.value.connection.name
  location            = var.location
  resource_group_name = var.resource_group_name

  type                       = each.value.connection.type
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.this[each.key].id

  enable_bgp                     = var.bgp.enable
  local_azure_ip_address_enabled = var.network.private_ip_address_enabled
  shared_key                     = each.value.connection.shared_key

  dynamic "custom_bgp_addresses" {
    for_each = each.value.custom_bgp_addresses
    content {
      primary   = var.azure_bgp_peer_addresses[custom_bgp_addresses.value.primary_key]
      secondary = try(var.azure_bgp_peer_addresses[custom_bgp_addresses.value.secondary_key], null)
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
