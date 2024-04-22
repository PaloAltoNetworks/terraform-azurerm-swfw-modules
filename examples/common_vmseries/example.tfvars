# GENERAL

region              = "North Europe"
resource_group_name = "transit-vnet-common"
name_prefix         = "example-"
tags = {
  "CreatedBy"     = "Palo Alto Networks"
  "CreatedWith"   = "Terraform"
  "xdr-exclusion" = "yes"
}

# NETWORK

vnets = {
  "transit" = {
    name          = "transit"
    address_space = ["10.0.0.0/25"]
    network_security_groups = {
      "management" = {
        name = "mgmt-nsg"
        rules = {
          mgmt_inbound = {
            name                       = "vmseries-management-allow-inbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefixes    = ["1.1.1.1/32"] # TODO: Whitelist public IP addresses that will be used to manage the appliances
            source_port_range          = "*"
            destination_address_prefix = "10.0.0.0/28"
            destination_port_ranges    = ["22", "443"]
          }
        }
      }
      "public" = {
        name = "public-nsg"
      }
    }
    route_tables = {
      "management" = {
        name = "mgmt-rt"
        routes = {
          "private_blackhole" = {
            name           = "private-blackhole-udr"
            address_prefix = "10.0.0.16/28"
            next_hop_type  = "None"
          }
          "public_blackhole" = {
            name           = "public-blackhole-udr"
            address_prefix = "10.0.0.32/28"
            next_hop_type  = "None"
          }
          "appgw_blackhole" = {
            name           = "appgw-blackhole-udr"
            address_prefix = "10.0.0.48/28"
            next_hop_type  = "None"
          }
        }
      }
      "private" = {
        name = "private-rt"
        routes = {
          "default" = {
            name                = "default-udr"
            address_prefix      = "0.0.0.0/0"
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = "10.0.0.30"
          }
          "mgmt_blackhole" = {
            name           = "mgmt-blackhole-udr"
            address_prefix = "10.0.0.0/28"
            next_hop_type  = "None"
          }
          "public_blackhole" = {
            name           = "public-blackhole-udr"
            address_prefix = "10.0.0.32/28"
            next_hop_type  = "None"
          }
          "appgw_blackhole" = {
            name           = "appgw-blackhole-udr"
            address_prefix = "10.0.0.48/28"
            next_hop_type  = "None"
          }
        }
      }
      "public" = {
        name = "public-rt"
        routes = {
          "mgmt_blackhole" = {
            name           = "mgmt-blackhole-udr"
            address_prefix = "10.0.0.0/28"
            next_hop_type  = "None"
          }
          "private_blackhole" = {
            name           = "private-blackhole-udr"
            address_prefix = "10.0.0.16/28"
            next_hop_type  = "None"
          }
        }
      }
    }
    subnets = {
      "management" = {
        name                            = "mgmt-snet"
        address_prefixes                = ["10.0.0.0/28"]
        network_security_group_key      = "management"
        route_table_key                 = "management"
        enable_storage_service_endpoint = true
      }
      "private" = {
        name             = "private-snet"
        address_prefixes = ["10.0.0.16/28"]
        route_table_key  = "private"
      }
      "public" = {
        name                       = "public-snet"
        address_prefixes           = ["10.0.0.32/28"]
        network_security_group_key = "public"
        route_table_key            = "public"
      }
      "appgw" = {
        name             = "appgw-snet"
        address_prefixes = ["10.0.0.48/28"]
      }
    }
  }
}

vnet_peerings = {
  # "vmseries-to-panorama" = {
  #   local_vnet_name            = "example-transit"
  #   remote_vnet_name           = "example-panorama-vnet"
  #   remote_resource_group_name = "example-panorama"
  # }
}

# LOAD BALANCING

load_balancers = {
  "public" = {
    name = "public-lb"
    nsg_auto_rules_settings = {
      nsg_vnet_key = "transit"
      nsg_key      = "public"
      source_ips   = ["1.1.1.1/32"] # TODO: Whitelist public IP addresses that will be used to access LB
    }
    frontend_ips = {
      "app1" = {
        name             = "app1"
        public_ip_name   = "public-lb-app1-pip"
        create_public_ip = true
        in_rules = {
          "balanceHttp" = {
            name     = "HTTP"
            protocol = "Tcp"
            port     = 80
          }
        }
      }
    }
  }
  "private" = {
    name     = "private-lb"
    vnet_key = "transit"
    frontend_ips = {
      "ha-ports" = {
        name               = "private-vmseries"
        subnet_key         = "private"
        private_ip_address = "10.0.0.30"
        in_rules = {
          HA_PORTS = {
            name     = "HA-ports"
            port     = 0
            protocol = "All"
          }
        }
      }
    }
  }
}

appgws = {
  public = {
    name       = "appgw"
    vnet_key   = "transit"
    subnet_key = "appgw"
    public_ip = {
      name = "appgw-pip"
    }
    listeners = {
      "http" = {
        name = "http"
        port = 80
      }
    }
    backend_settings = {
      http = {
        name     = "http"
        port     = 80
        protocol = "Http"
      }
    }
    rewrites = {
      xff = {
        name = "XFF-set"
        rules = {
          "xff-strip-port" = {
            name     = "xff-strip-port"
            sequence = 100
            request_headers = {
              "X-Forwarded-For" = "{var_add_x_forwarded_for_proxy}"
            }
          }
        }
      }
    }
    rules = {
      "http" = {
        name         = "http"
        listener_key = "http"
        backend_key  = "http"
        rewrite_key  = "xff"
        priority     = 1
      }
    }
  }
}

# VM-SERIES

vmseries = {
  "fw-1" = {
    name     = "firewall01"
    vnet_key = "transit"
    image = {
      version = "10.2.901"
    }
    virtual_machine = {
      size              = "Standard_DS3_v2"
      zone              = 1
      bootstrap_options = "type=dhcp-client"
    }
    interfaces = [
      {
        name             = "vm01-mgmt"
        subnet_key       = "management"
        create_public_ip = true
      },
      {
        name              = "vm01-private"
        subnet_key        = "private"
        load_balancer_key = "private"
      },
      {
        name                    = "vm01-public"
        subnet_key              = "public"
        create_public_ip        = true
        load_balancer_key       = "public"
        application_gateway_key = "public"
      }
    ]
  }
  "fw-2" = {
    name = "firewall02"
    image = {
      version = "10.2.901"
    }
    virtual_machine = {
      size              = "Standard_DS3_v2"
      zone              = 2
      bootstrap_options = "type=dhcp-client"
    }
    vnet_key = "transit"
    interfaces = [
      {
        name             = "vm02-mgmt"
        subnet_key       = "management"
        create_public_ip = true
      },
      {
        name              = "vm02-private"
        subnet_key        = "private"
        load_balancer_key = "private"
      },
      {
        name                    = "vm02-public"
        subnet_key              = "public"
        create_public_ip        = true
        load_balancer_key       = "public"
        application_gateway_key = "public"
      }
    ]
  }
}

# TEST INFRASTRUCTURE

test_infrastructure = {
  "app1_testenv" = {
    vnets = {
      "app1" = {
        name          = "app1-vnet"
        address_space = ["10.100.0.0/25"]
        hub_vnet_name = "transit" # Name prefix is added to the beginning of this string
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
                source_address_prefixes    = ["1.1.1.1/32"] # TODO: Whitelist public IP addresses that will be used to access test infrastructure
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
                next_hop_ip_address = "10.0.0.30"
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
        hub_vnet_name = "transit" # Name prefix is added to the beginning of this string
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
                source_address_prefixes    = ["1.1.1.1/32"] # TODO: Whitelist public IP addresses that will be used to access test infrastructure
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
                next_hop_ip_address = "10.0.0.30"
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
