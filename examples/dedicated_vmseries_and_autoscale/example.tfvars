# GENERAL

region              = "North Europe"
resource_group_name = "autoscale-dedicated"
name_prefix         = "example-"
tags = {
  "CreatedBy"   = "Palo Alto Networks"
  "CreatedWith" = "Terraform"
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
            source_address_prefixes    = ["0.0.0.0/0"]
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
    }
  }
}

natgws = {
  "natgw" = {
    name        = "public-natgw"
    vnet_key    = "transit"
    subnet_keys = ["public", "management"]
    public_ip_prefix = {
      create = true
      name   = "public-natgw-ippre"
      length = 29
    }
  }
}

# LOAD BALANCING

load_balancers = {
  "public" = {
    name  = "public-lb"
    zones = null
    nsg_auto_rules_settings = {
      nsg_vnet_key = "transit"
      nsg_key      = "public"
      source_ips   = ["0.0.0.0/0"] # Put your own public IP address here  <-- TODO to be adjusted by the customer
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
    zones    = null
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

# VM-SERIES

ngfw_metrics = {
  name = "ngwf-log-analytics-wrksp"
}

scale_sets = {
  inbound = {
    name     = "inbound-vmss"
    vnet_key = "transit"
    image = {
      version = "10.2.4"
    }
    authentication = {
      disable_password_authentication = false
    }
    virtual_machine_scale_set = {
      bootstrap_options = "type=dhcp-client"
      zones             = null
    }
    autoscaling_configuration = {
      default_count = 2
    }
    interfaces = [
      {
        name       = "management"
        subnet_key = "management"
      },
      {
        name       = "private"
        subnet_key = "private"
      },
      {
        name              = "public"
        subnet_key        = "public"
        load_balancer_key = "public"
      }
    ]
  }
  obew = {
    name     = "obew-vmss"
    vnet_key = "transit"
    image = {
      version = "10.2.4"
    }
    authentication = {
      disable_password_authentication = false
    }
    virtual_machine_scale_set = {
      bootstrap_options = "type=dhcp-client"
      zones             = null
    }
    autoscaling_configuration = {
      default_count = 2
    }
    interfaces = [
      {
        name       = "management"
        subnet_key = "management"
      },
      {
        name              = "private"
        subnet_key        = "private"
        load_balancer_key = "private"
      },
      {
        name       = "public"
        subnet_key = "public"
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
        hub_vnet_name = "example-transit"
        network_security_groups = {
          "app1" = {
            name = "app1-nsg"
            rules = {
              web_inbound = {
                name                       = "app1-web-allow-inbound"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefixes    = ["134.238.135.14", "134.238.135.140"]
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
        hub_vnet_name = "example-transit"
        network_security_groups = {
          "app2" = {
            name = "app2-nsg"
            rules = {
              web_inbound = {
                name                       = "app2-web-allow-inbound"
                priority                   = 100
                direction                  = "Inbound"
                access                     = "Allow"
                protocol                   = "Tcp"
                source_address_prefixes    = ["134.238.135.14", "134.238.135.140"]
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
