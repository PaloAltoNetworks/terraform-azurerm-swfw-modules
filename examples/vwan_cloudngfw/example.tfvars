# GENERAL

subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "North Europe"
resource_group_name = "cloudngfw-vwan"
name_prefix         = "example-"
tags = {
  "CreatedBy"     = "Palo Alto Networks"
  "CreatedWith"   = "Terraform"
  "xdr-exclusion" = "yes"
}

# NETWORK

vnets = {
  /* Uncomment the section below to source the Panorama VNET in order to connect it to a vHub
  "panorama" = {
    name                   = "example-panorama-vnet"
    resource_group_name    = "example-panorama"
    create_virtual_network = false
  }
  */
}

virtual_wan = {
  name = "virtual_wan"
  virtual_hubs = {
    "virtual_hub" = {
      name           = "virtual_hub"
      address_prefix = "11.0.0.0/24"
      connections = {
        /* Uncomment the section below to connect the Panorama VNET to a vHub
        "panorama-to-hub" = {
          name                       = "panorama-to-hub"
          connection_type            = "Vnet"
          remote_virtual_network_key = "panorama"
        }
        */
        "app1-to-hub" = {
          name                       = "app1-to-hub"
          connection_type            = "Vnet"
          remote_virtual_network_key = "app1"
        }
        "app2-to-hub" = {
          name                       = "app2-to-hub"
          connection_type            = "Vnet"
          remote_virtual_network_key = "app2"
        }
      }
      routing_intent = {
        routing_intent_name = "routing_intent"
        routing_policy = [
          {
            routing_policy_name = "PrivateTraffic"
            destinations        = ["PrivateTraffic"]
            next_hop_key        = "cloudngfw"
          },
          {
            routing_policy_name = "Internet"
            destinations        = ["Internet"]
            next_hop_key        = "cloudngfw"
          }
        ]
      }
    }
  }
}

# CLOUDNGFW

cloudngfws = {
  "cloudngfw" = {
    name            = "cloudngfw"
    attachment_type = "vwan"
    management_mode = "panorama"
    virtual_hub_key = "virtual_hub"
    cloudngfw_config = {
      panorama_base64_config = "eyJkZ25hbWUiOiAiY25nZnctYXotdmh1YiIsICJ0cGxuYW1lIjogImNuZ2Z3LWF6LXZodWIiLCAicGFub3JhbWEtc2VydmVyIjogIjE5Mi4xNjguMS4xMCIsICJjZ25hbWUiOiAiY29sbGVjdG9yX0ciLCAidm0tYXV0aC1rZXkiOiAiMDgxOTgxODY4NzU5MzI4IiwgImV4cGlyeSI6ICIyMDI1LzExLzE0In0=" # TODO: Put panorama connection string
      destination_nats = {
        "app1-tcp80-dnat" = {
          destination_nat_name     = "app1-tcp80-dnat"
          destination_nat_protocol = "TCP"
          frontend_port            = 80
          backend_port             = 80
          backend_ip_address       = "10.100.0.4"
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
        address_space = ["10.100.0.0/25"]
        network_security_groups = {
          "app1" = {
            name = "app1-nsg"
            rules = {
              from_bastion = {
                name                       = "app1-mgmt-allow-bastion"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "*"
                source_address_prefix      = "*"
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
              web_inbound = {
                name                       = "app1-web-allow-inbound"
                priority                   = 110
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "*"
                source_address_prefix      = "*"
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                       = "vms-snet"
            address_prefixes           = ["10.100.0.0/26"]
            network_security_group_key = "app1"
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
        network_security_groups = {
          "app2" = {
            name = "app2-nsg"
            rules = {
              from_bastion = {
                name                       = "app2-mgmt-allow-bastion"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "*"
                source_address_prefix      = "*"
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
              web_inbound = {
                name                       = "app2-web-allow-inbound"
                priority                   = 110
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "*"
                source_address_prefix      = "*" # TODO: Whitelist public IP addresses that will be used to access test infrastructure
                source_port_range          = "*"
                destination_address_prefix = "*"
                destination_port_range     = "*"
              }
            }
          }
        }
        subnets = {
          "vms" = {
            name                       = "vms-snet"
            address_prefixes           = ["10.100.1.0/26"]
            network_security_group_key = "app2"
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
