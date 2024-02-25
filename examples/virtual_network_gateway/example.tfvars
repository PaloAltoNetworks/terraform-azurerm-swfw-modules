# --- GENERAL --- #
location            = "North Europe"
resource_group_name = "vng"
name_prefix         = "example-"
tags = {
  "CreatedBy"   = "Palo Alto Networks"
  "CreatedWith" = "Terraform"
}


# --- VNET PART --- #
vnets = {
  transit = {
    name                    = "transit"
    address_space           = ["10.0.0.0/24"]
    network_security_groups = {}
    route_tables = {
      "rt" = {
        name = "rt"
        routes = {
          "udr" = {
            name           = "udr"
            address_prefix = "10.0.0.0/8"
            next_hop_type  = "None"
          }
        }
      }
    }
    subnets = {
      vpn = {
        name             = "GatewaySubnet"
        address_prefixes = ["10.0.0.0/25"]
        route_table_key  = "rt"
      }
    }
  }
  er = {
    name                    = "vpn"
    address_space           = ["10.0.1.0/24"]
    network_security_groups = {}
    route_tables = {
      "rt" = {
        name = "rt-er"
        routes = {
          "udr" = {
            name           = "udr"
            address_prefix = "10.0.0.0/8"
            next_hop_type  = "None"
          }
        }
      }
    }
    subnets = {
      vpn = {
        name             = "GatewaySubnet"
        address_prefixes = ["10.0.1.0/25"]
        route_table_key  = "rt"
      }
    }
  }
}

# --- VNG PART --- #
virtual_network_gateways = {
  expressroute = {
    name       = "expressroute"
    vnet_key   = "transit"
    subnet_key = "vpn"
    zones      = ["1"]

    type       = "ExpressRoute"
    vpn_type   = "RouteBased"
    generation = "Generation1"
    sku        = "Standard"

    network = {
      ip_configurations = {
        primary = {
          create_public_ip = true
          name             = "primary"
          public_ip_name   = "expressroute_pip"
        }
      }
    }
  }
  expressroute_policy_based = {
    name       = "er_policy"
    vnet_key   = "er"
    subnet_key = "vpn"
    zones      = ["1"]

    type       = "ExpressRoute"
    vpn_type   = "PolicyBased"
    generation = "Generation2"
    sku        = "Standard"

    network = {
      ip_configurations = {
        primary = {
          create_public_ip = true
          name             = "primary"
          public_ip_name   = "er_policy_pip"
        }
      }
    }
  }
  vpn_simple = {
    name       = "simple-vpn"
    vnet_key   = "er"
    subnet_key = "vpn"
    zones      = []

    type       = "Vpn"
    vpn_type   = "PolicyBased"
    generation = "Generation1"
    sku        = "VpnGw1"

    network = {
      ip_configurations = {
        primary = {
          create_public_ip = true
          name             = "primary"
          public_ip_name   = "simple_vpn_pip"
        }
      }
    }
  }
  "vng" = {
    name       = "vng"
    vnet_key   = "transit"
    subnet_key = "vpn"
    zones      = ["1", "2", "3"]

    type          = "Vpn"
    generation    = "Generation2"
    sku           = "VpnGw2AZ"
    active_active = true

    network = {
      ip_configurations = {
        primary = {
          name             = "primary"
          create_public_ip = true
          public_ip_name   = "vng-primary-pip"
        }
        secondary = {
          name             = "secondary"
          create_public_ip = true
          public_ip_name   = "vng-secondary-pip"
        }
      }
    }
    azure_bgp_peer_addresses = {
      one_primary     = "169.254.21.2"
      one_secondary   = "169.254.22.2"
      two_primary     = "169.254.21.12"
      two_secondary   = "169.254.22.12"
      three_primary   = "169.254.21.22"
      three_secondary = "169.254.22.22"
    }
    bgp = {
      enable = true
      configuration = {
        asn = "65002"
        primary_peering_addresses = {
          name               = "primary"
          apipa_address_keys = ["one_primary", "two_primary", "three_primary"]
        }
        secondary_peering_addresses = {
          name               = "secondary"
          apipa_address_keys = ["one_secondary", "two_secondary", "three_secondary"]
        }
      }
    }
    local_network_gateways = {
      lg1 = {
        name            = "local_gw_1"
        gateway_address = "8.8.8.8"
        remote_bgp_settings = {
          asn                 = "65000"
          bgp_peering_address = "169.254.21.1"
        }
        connection = {
          name = "connection_1"
          custom_bgp_addresses = {
            primary_key   = "one_primary"
            secondary_key = "one_secondary"
          }
          mode       = "InitiatorOnly"
          shared_key = "test123"
          ipsec_policies = [
            {
              dh_group         = "ECP384"
              ike_encryption   = "AES256"
              ike_integrity    = "SHA256"
              ipsec_encryption = "AES256"
              ipsec_integrity  = "SHA256"
              pfs_group        = "ECP384"
              sa_datasize      = "102400000"
              sa_lifetime      = "14400"
            }
          ]
        }
      }
      lg2 = {
        name            = "local_gw_2"
        gateway_address = "4.4.4.4"
        remote_bgp_settings = {
          asn                 = "65000"
          bgp_peering_address = "169.254.22.1"
        }
        connection = {
          name = "connection_2"
          custom_bgp_addresses = {
            primary_key   = "two_primary"
            secondary_key = "two_secondary"
          }
          mode       = "InitiatorOnly"
          shared_key = "test123"
          ipsec_policies = [
            {
              dh_group         = "ECP384"
              ike_encryption   = "AES256"
              ike_integrity    = "SHA256"
              ipsec_encryption = "AES256"
              ipsec_integrity  = "SHA256"
              pfs_group        = "ECP384"
              sa_datasize      = "102400000"
              sa_lifetime      = "14400"
            }
          ]
        }
      }
    }
  }
}
