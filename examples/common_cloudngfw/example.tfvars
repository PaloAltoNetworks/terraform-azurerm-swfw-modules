# GENERAL
subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "East US"
resource_group_name = "common-cloudngfw"
name_prefix         = "example-"
tags = {
  "CreatedBy"     = "palo-alto-networks"
  "CreatedWith"   = "Terraform"
  "xdr-exclusion" = "yes"
}

# NETWORK
vnets = {
  "cngfw-vnet" = {
    name          = "cngfw-vnet"
    address_space = ["10.0.0.0/25"]
    network_security_groups = {
      "cngfw-dnat-ports-allow-nsg" = {
        name = "cngfw-dnat-ports-allow-nsg"
        rules = {
          cngfw-dnat-ports-allow = {
            name                         = "cngfw-dnat-ports-allow"
            priority                     = 100
            direction                    = "Inbound"
            access                       = "Allow"
            protocol                     = "Tcp"
            source_address_prefixes      = ["0.0.0.0/0"] # TODO: Whitelist public IP addresses that will be used to access test infrastructure
            source_port_range            = "*"
            destination_address_prefixes = ["0.0.0.0/0"]
            destination_port_ranges      = ["80", "443"]
          }
        }
      }
    }
    subnets = {
      "trusted" = {
        name                        = "trusted"
        address_prefixes            = ["10.0.0.0/26"]
        network_security_group_key  = "cngfw-dnat-ports-allow-nsg"
        enable_cloudngfw_delegation = true

      }
      "untrusted" = {
        name                        = "untrusted"
        address_prefixes            = ["10.0.0.64/26"]
        network_security_group_key  = "cngfw-dnat-ports-allow-nsg"
        enable_cloudngfw_delegation = true
      }
    }
  }
}

#PUBLIC_IP
public_ips = {
  public_ip_addresses = {
    cngfw_public_ip_app1 = {
      create = true
      name   = "cngfw_public_ip_app1"
    }
    cngfw_public_ip_app2 = {
      create = true
      name   = "cngfw_public_ip_app2"
    }
  }
}

#CNGFW
cngfws = {
  "cngfw" = {
    attachment_type      = "vnet"
    management_mode      = "panorama"
    virtual_network_key  = "cngfw-vnet"
    trusted_subnet_key   = "trusted"
    untrusted_subnet_key = "untrusted"
    cngfw_config = {
      cngfw_name                 = "cngfw"
      public_ip_keys             = ["cngfw_public_ip_app1", "cngfw_public_ip_app2"]
      egress_nat_ip_address_keys = ["cngfw_public_ip_app1"]
      panorama_base64_config     = "" # TODO: Put panorama connection string
      destination_nat = {
        "app1-443tcp-dnat" = {
          destination_nat_name     = "app1-443tcp-dnat"
          destination_nat_protocol = "TCP"
          frontend_public_ip_key   = "cngfw_public_ip_app1"
          frontend_port            = 443
          backend_port             = 443
          backend_ip_address       = "10.100.0.4"
        }
        "app1-80tcp-dnat" = {
          destination_nat_name     = "app1-80tcp-dnat"
          destination_nat_protocol = "TCP"
          frontend_public_ip_key   = "cngfw_public_ip_app1"
          frontend_port            = 80
          backend_port             = 80
          backend_ip_address       = "10.100.0.4"
        }
        "app2-443tcp-dnat" = {
          destination_nat_name     = "app2-443tcp-dnat"
          destination_nat_protocol = "TCP"
          frontend_public_ip_key   = "cngfw_public_ip_app2"
          frontend_port            = 443
          backend_port             = 443
          backend_ip_address       = "10.100.1.4"
        }
        "app2-80tcp-dnat" = {
          destination_nat_name     = "app2-80tcp-dnat"
          destination_nat_protocol = "TCP"
          frontend_public_ip_key   = "cngfw_public_ip_app2"
          frontend_port            = 80
          backend_port             = 80
          backend_ip_address       = "10.100.1.4"
        }
      }
    }
  }
}

# #VNET-PEERING
# vnet_peerings = { #Uncomment the section below to peer CNGFW VNET with Panorama VNET to manage cngfw through Panorama.
#   "cngfw-to-panorama" = {
#     local_vnet_name            = "example-cngfw-vnet"
#     remote_vnet_name           = "example-panorama-vnet"
#     remote_resource_group_name = "example-panorama"
# }

# TEST INFRASTRUCTURE
test_infrastructure = {
  "app1_testenv" = {
    vnets = {
      "app1" = {
        name          = "app1-vnet"
        address_space = ["10.100.0.0/25"]
        hub_vnet_name = "cngfw-vnet" # Name prefix is added to the beginning of this string
        network_security_groups = {
          "app1" = {
            name = "app1-nsg"
            rules = {
              from_bastion = {
                name                       = "app1-mgmt-allow-bastion"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefix      = "10.100.0.64/26"
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
              web_inbound = {
                name                       = "app1-web-allow-inbound"
                priority                   = 110
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefixes    = ["0.0.0.0/0"] # TODO: Whitelist public IP addresses that will be used to access test infrastructure
                source_port_range          = "*"
                destination_address_prefix = "10.100.0.0/25"
                destination_port_ranges    = ["80", "443"]
              }
            }
          }
        }
        route_tables = {
          nva = {
            name = "app1-rt"
            routes = {
              "toNVA" = {
                name                = "toNVA-udr"
                address_prefix      = "0.0.0.0/0"
                next_hop_type       = "VirtualAppliance"
                next_hop_ip_address = "10.0.0.4"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                       = "vms-snet"
            address_prefixes           = ["10.100.0.0/26"]
            network_security_group_key = "app1"
            route_table_key            = "nva"
          }
          "bastion" = {
            name             = "AzureBastionSubnet"
            address_prefixes = ["10.100.0.64/26"]
          }
        }
      }
    }
    spoke_vms = {
      "app1_vm" = {
        name       = "app1-vm"
        vnet_key   = "app1"
        subnet_key = "vms"
      }
    }
    bastions = {
      "app1_bastion" = {
        name       = "app1-bastion"
        vnet_key   = "app1"
        subnet_key = "bastion"
      }
    }
  }
  "app2_testenv" = {
    vnets = {
      "app2" = {
        name          = "app2-vnet"
        address_space = ["10.100.1.0/25"]
        hub_vnet_name = "cngfw-vnet" # Name prefix is added to the beginning of this string
        network_security_groups = {
          "app2" = {
            name = "app2-nsg"
            rules = {
              from_bastion = {
                name                       = "app2-mgmt-allow-bastion"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefix      = "10.100.1.64/26"
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
              web_inbound = {
                name                       = "app2-web-allow-inbound"
                priority                   = 110
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefixes    = ["0.0.0.0/0"] # TODO: Whitelist public IP addresses that will be used to access test infrastructure
                source_port_range          = "*"
                destination_address_prefix = "10.100.1.0/25"
                destination_port_ranges    = ["80", "443"]
              }
            }
          }
        }
        route_tables = {
          nva = {
            name = "app2-rt"
            routes = {
              "toNVA" = {
                name                = "toNVA-udr"
                address_prefix      = "0.0.0.0/0"
                next_hop_type       = "VirtualAppliance"
                next_hop_ip_address = "10.0.0.4"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                       = "vms-snet"
            address_prefixes           = ["10.100.1.0/26"]
            network_security_group_key = "app2"
            route_table_key            = "nva"
          }
          "bastion" = {
            name             = "AzureBastionSubnet"
            address_prefixes = ["10.100.1.64/26"]
          }
        }
      }
    }
    spoke_vms = {
      "app2_vm" = {
        name       = "app2-vm"
        vnet_key   = "app2"
        subnet_key = "vms"
      }
    }
    bastions = {
      "app2_bastion" = {
        name       = "app2-bastion"
        vnet_key   = "app2"
        subnet_key = "bastion"
      }
    }
  }
}