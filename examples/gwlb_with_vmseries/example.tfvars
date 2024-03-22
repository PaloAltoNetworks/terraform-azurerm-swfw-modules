# GENERAL

region              = "North Europe"
resource_group_name = "gwlb"
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
            source_address_prefixes    = ["0.0.0.0/0"] # TODO: whitelist public IP addresses that will be used to manage the appliances
            source_port_range          = "*"
            destination_address_prefix = "10.0.0.0/28"
            destination_port_ranges    = ["22", "443"]
          }
        }
      }
      "data" = {
        name = "data-nsg"
      }
    }
    route_tables = {
      "management" = {
        name = "mgmt-rt"
        routes = {
          "data_blackhole" = {
            name           = "data-blackhole-udr"
            address_prefix = "10.0.0.16/28"
            next_hop_type  = "None"
          }
        }
      }
      "data" = {
        name = "data-rt"
        routes = {
          "mgmt_blackhole" = {
            name           = "mgmt-blackhole-udr"
            address_prefix = "10.0.0.0/28"
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
      "data" = {
        name                       = "data-snet"
        address_prefixes           = ["10.0.0.16/28"]
        network_security_group_key = "data"
        route_table_key            = "data"
      }
    }
  }
}

# LOAD BALANCING

gateway_load_balancers = {
  gwlb = {
    name = "vmseries-gwlb"

    frontend_ip = {
      vnet_key   = "transit"
      subnet_key = "data"
    }

    health_probe = {
      name     = "custom-health-probe"
      port     = 80
      protocol = "Tcp"
    }

    backends = {
      backend = {
        name = "custom-backend"
        tunnel_interfaces = {
          internal = {
            identifier = 800
            port       = 2000
            protocol   = "VXLAN"
            type       = "Internal"
          }
          external = {
            identifier = 801
            port       = 2001
            protocol   = "VXLAN"
            type       = "External"
          }
        }
      }
    }

    lb_rule = {
      name = "custom-lb-rule"
    }
  }
}

# VM-SERIES

bootstrap_storages = {
  "bootstrap" = {
    name = "examplegwlbbootstrap"
    storage_network_security = {
      vnet_key            = "transit"
      allowed_subnet_keys = ["management"]
      allowed_public_ips  = ["0.0.0.0/0"] # TODO: whitelist public IP addresses that will be used to manage the appliances
    }
  }
}

vmseries = {
  "fw-1" = {
    name     = "firewall01"
    vnet_key = "transit"
    image = {
      version = "10.2.3"
    }
    virtual_machine = {
      size = "Standard_DS3_v2"
      zone = 1
      bootstrap_package = {
        bootstrap_storage_key  = "bootstrap"
        static_files           = { "files/init-cfg.txt" = "config/init-cfg.txt" }
        bootstrap_xml_template = "templates/bootstrap-gwlb.tftpl"
        data_snet_key          = "data"
      }
    }
    interfaces = [
      {
        name             = "vm01-mgmt"
        subnet_key       = "management"
        create_public_ip = true
      },
      {
        name             = "vm01-data"
        subnet_key       = "data"
        gwlb_key         = "gwlb"
        gwlb_backend_key = "backend"
      }
    ]
  }
  "fw-2" = {
    name     = "firewall02"
    vnet_key = "transit"
    image = {
      version = "10.2.3"
    }
    virtual_machine = {
      size = "Standard_DS3_v2"
      zone = 2
      bootstrap_package = {
        bootstrap_storage_key  = "bootstrap"
        static_files           = { "files/init-cfg.txt" = "config/init-cfg.txt" }
        bootstrap_xml_template = "templates/bootstrap-gwlb.tftpl"
        data_snet_key          = "data"
      }
    }
    interfaces = [
      {
        name             = "vm02-mgmt"
        subnet_key       = "management"
        create_public_ip = true
      },
      {
        name             = "vm02-data"
        subnet_key       = "data"
        gwlb_key         = "gwlb"
        gwlb_backend_key = "backend"
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
    load_balancers = {
      "app1" = {
        name = "app1-lb"
        nsg_auto_rules_settings = {
          nsg_vnet_key = "app1"
          nsg_key      = "app1"
          source_ips   = ["0.0.0.0/0"]
        }
        frontend_ips = {
          "app1" = {
            name             = "app1-frontend"
            public_ip_name   = "public-lb-app1-frontend-pip"
            create_public_ip = true
            gwlb_key         = "gwlb"
            in_rules = {
              "balanceHttp" = {
                name        = "HTTP"
                protocol    = "Tcp"
                port        = 80
                floating_ip = false
              }
              "balanceHttps" = {
                name        = "HTTPS"
                protocol    = "Tcp"
                port        = 443
                floating_ip = false
              }
            }
            out_rules = {
              outbound = {
                name     = "tcp-outbound"
                protocol = "Tcp"
              }
            }
          }
        }
      }
    }
    spoke_vms = {
      "app1_vm" = {
        name              = "app1-vm"
        vnet_key          = "app1"
        subnet_key        = "vms"
        load_balancer_key = "app1"
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
    load_balancers = {
      "app2" = {
        name = "app2-lb"
        nsg_auto_rules_settings = {
          nsg_vnet_key = "app2"
          nsg_key      = "app2"
          source_ips   = ["0.0.0.0/0"]
        }
        frontend_ips = {
          "app2" = {
            name             = "app2-frontend"
            public_ip_name   = "public-lb-app2-frontend-pip"
            create_public_ip = true
            gwlb_key         = "gwlb"
            in_rules = {
              "balanceHttp" = {
                name        = "HTTP"
                protocol    = "Tcp"
                port        = 80
                floating_ip = false
              }
              "balanceHttps" = {
                name        = "HTTPS"
                protocol    = "Tcp"
                port        = 443
                floating_ip = false
              }
            }
            out_rules = {
              outbound = {
                name     = "tcp-outbound"
                protocol = "Tcp"
              }
            }
          }
        }
      }
    }
    spoke_vms = {
      "app2_vm" = {
        name              = "app2-vm"
        vnet_key          = "app2"
        subnet_key        = "vms"
        load_balancer_key = "app2"
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
