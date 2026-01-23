# GENERAL

subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "North Europe"
resource_group_name = "cloudngfw-vnet-distributed"
name_prefix         = "example-"
tags = {
  "CreatedBy"     = "Palo Alto Networks"
  "CreatedWith"   = "Terraform"
  "xdr-exclusion" = "yes"
}

# NETWORK

vnets = {
  /* Uncomment the section below to source the Panorama VNET in order to connect it to Spoke VNETs
  "panorama" = {
    name                   = "example-panorama-vnet"
    resource_group_name    = "example-panorama"
    create_virtual_network = false
  }
  */
}

# CLOUDNGFW

cloudngfws = {
  "cloudngfw1" = {
    name                 = "cloudngfw1"
    attachment_type      = "vnet"
    virtual_network_key  = "app1"
    untrusted_subnet_key = "public"
    trusted_subnet_key   = "private"
    management_mode      = "panorama"
    cloudngfw_config = {
      panorama_base64_config = "eyJkZ25hbWUiOiAiY25nZnctYXotZXhhbXBsZSIsICJ0cGxuYW1lIjogImNuZ2Z3LWF6LWV4YW1wbGUiLCAicGFub3JhbWEtc2VydmVyIjogIjEuMS4xLjEiLCAidm0tYXV0aC1rZXkiOiAiMTExMTExMTExMTExMTExIiwgImV4cGlyeSI6ICIyOTk5LzAxLzAxIn0=" # TODO: Put panorama base64 connection string
      destination_nats = {
        "app1-tcp80-dnat" = {
          destination_nat_name     = "app1-tcp80-dnat"
          destination_nat_protocol = "TCP"
          frontend_port            = 80
          backend_port             = 80
          backend_ip_address       = "10.100.0.4"
        }
        "app1-tcp443-dnat" = {
          destination_nat_name     = "app1-tcp443-dnat"
          destination_nat_protocol = "TCP"
          frontend_port            = 443
          backend_port             = 443
          backend_ip_address       = "10.100.0.4"
        }
      }
    }
  }
  "cloudngfw2" = {
    name                 = "cloudngfw2"
    attachment_type      = "vnet"
    virtual_network_key  = "app2"
    untrusted_subnet_key = "public"
    trusted_subnet_key   = "private"
    management_mode      = "panorama"
    cloudngfw_config = {
      panorama_base64_config = "eyJkZ25hbWUiOiAiY25nZnctYXotZXhhbXBsZSIsICJ0cGxuYW1lIjogImNuZ2Z3LWF6LWV4YW1wbGUiLCAicGFub3JhbWEtc2VydmVyIjogIjEuMS4xLjEiLCAidm0tYXV0aC1rZXkiOiAiMTExMTExMTExMTExMTExIiwgImV4cGlyeSI6ICIyOTk5LzAxLzAxIn0=" # TODO: Put panorama base64 connection string
      destination_nats = {
        "app2-tcp80-dnat" = {
          destination_nat_name     = "app2-tcp80-dnat"
          destination_nat_protocol = "TCP"
          frontend_port            = 80
          backend_port             = 80
          backend_ip_address       = "10.100.1.4"
        }
        "app2-tcp443-dnat" = {
          destination_nat_name     = "app2-tcp443-dnat"
          destination_nat_protocol = "TCP"
          frontend_port            = 443
          backend_port             = 443
          backend_ip_address       = "10.100.1.4"
        }
      }
    }
  }
}

# TEST INFRASTRUCTURE

test_infrastructure = {
  "app1_testenv" = {
    vnets = {
      "app1" = {
        name          = "app1-vnet"
        address_space = ["10.100.0.0/24"]
        /* Uncomment the section below to peer this VNET with the Panorama VNET
        hub_vnet_key  = "panorama"
        */
        network_security_groups = {
          "cloudngfw1-dnat" = {
            name = "cloudngfw1-dnat-nsg"
            rules = {
              cloudngfw-dnat-ports-allow = {
                name                         = "cloudngfw-dnat-ports-allow"
                priority                     = 100
                direction                    = "Inbound"
                access                       = "Allow"
                protocol                     = "Tcp"
                source_address_prefixes      = ["1.1.1.1/32"] # TODO: Whitelist IP addresses that will be used to access test infrastructure
                source_port_range            = "*"
                destination_address_prefixes = ["0.0.0.0/0"]
                destination_port_ranges      = ["80", "443"]
              }
            }
          }
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
                destination_address_prefix = "10.100.0.0/24"
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
                next_hop_ip_address = "10.100.0.196"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                              = "vms"
            address_prefixes                  = ["10.100.0.0/26"]
            private_endpoint_network_policies = "Enabled"
            network_security_group_key        = "app1"
            route_table_key                   = "nva"
          }
          "bastion" = {
            name             = "AzureBastionSubnet"
            address_prefixes = ["10.100.0.64/26"]
          }
          "public" = {
            name                              = "cloudngfw-public"
            address_prefixes                  = ["10.100.0.128/26"]
            private_endpoint_network_policies = "Enabled"
            network_security_group_key        = "cloudngfw1-dnat"
            enable_cloudngfw_delegation       = true
          }
          "private" = {
            name                        = "cloudngfw-private"
            address_prefixes            = ["10.100.0.192/26"]
            enable_cloudngfw_delegation = true
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
        address_space = ["10.100.1.0/24"]
        /* Uncomment the section below to peer this VNET with the Panorama VNET
        hub_vnet_key  = "panorama"
        */
        network_security_groups = {
          "cloudngfw2-dnat" = {
            name = "cloudngfw2-dnat-nsg"
            rules = {
              cloudngfw-dnat-ports-allow = {
                name                         = "cloudngfw-dnat-ports-allow"
                priority                     = 100
                direction                    = "Inbound"
                access                       = "Allow"
                protocol                     = "Tcp"
                source_address_prefixes      = ["1.1.1.1/32"] # TODO: Whitelist IP addresses that will be used to access test infrastructure
                source_port_range            = "*"
                destination_address_prefixes = ["0.0.0.0/0"]
                destination_port_ranges      = ["80", "443"]
              }
            }
          }
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
                destination_address_prefix = "10.100.1.0/24"
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
                next_hop_ip_address = "10.100.1.196"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                              = "vms"
            address_prefixes                  = ["10.100.1.0/26"]
            private_endpoint_network_policies = "Enabled"
            network_security_group_key        = "app2"
            route_table_key                   = "nva"
          }
          "bastion" = {
            name             = "AzureBastionSubnet"
            address_prefixes = ["10.100.1.64/26"]
          }
          "public" = {
            name                              = "cloudngfw-public"
            address_prefixes                  = ["10.100.1.128/26"]
            private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
            network_security_group_key        = "cloudngfw2-dnat"
            enable_cloudngfw_delegation       = true
          }
          "private" = {
            name                        = "cloudngfw-private"
            address_prefixes            = ["10.100.1.192/26"]
            enable_cloudngfw_delegation = true
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
