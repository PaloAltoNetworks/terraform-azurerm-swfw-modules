# GENERAL

subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "North Europe"
resource_group_name = "gwlb"
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
            source_address_prefixes    = ["1.1.1.1/32"] # TODO: Whitelist IP addresses that will be used to manage the appliances
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

vnet_peerings = {
  /* Uncomment the section below to peer Transit VNET with Panorama VNET (if you have one)
  "vmseries-to-panorama" = {
    local_vnet_name            = "example-transit"
    remote_vnet_name           = "example-panorama-vnet"
    remote_resource_group_name = "example-panorama"
  }
  */
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

/* Uncomment the section below to create a Storage Account for full bootstrap if you intend to use this bootstrap method
bootstrap_storages = {
  "bootstrap" = {
    name = "smplngfwbtstrp"
    storage_network_security = {
      vnet_key            = "transit"
      allowed_subnet_keys = ["management"]
      allowed_public_ips  = ["1.1.1.1/30"] # TODO: Whitelist public IP addresses that will be used to access storage account
    }
  }
}
*/

# All options under `vmseries_universal` map can be overwritten on a per-firewall basis under `vmseries` map
vmseries_universal = {
  version = "10.2.1009"
  size    = "Standard_DS3_v2"

  # This example uses basic user-data bootstrap method by default, comment out the map below if you want to use another one
  bootstrap_options = {
    type = "dhcp-client"
  }

  /* Uncomment the section below to use Panorama Software Firewall License (sw_fw_license) plugin bootstrap and fill out missing data
  bootstrap_options = {
    type               = "dhcp-client"
    plugin-op-commands = "panorama-licensing-mode-on"
    panorama-server    = "" # TODO: Insert Panorama IP address from sw_fw_license plugin
    tplname            = "" # TODO: Insert Panorama Template Stack name from sw_fw_license plugin
    dgname             = "" # TODO: Insert Panorama Device Group name from sw_fw_license plugin
    auth-key           = "" # TODO: Insert authentication key from sw_fw_license plugin
  }
  */

  /* Uncomment the section below to use Strata Cloud Manager (SCM) bootstrap and fill out missing data (PAN-OS version 11.0 or higher)
  bootstrap_options = {
    type                                  = "dhcp-client"
    plugin-op-commands                    = "advance-routing:enable"
    panorama-server                       = "cloud"
    tplname                               = "" # TODO: Insert SCM device label name 
    dgname                                = "" # TODO: Insert SCM Folder name
    vm-series-auto-registration-pin-id    = "" # TODO: Insert Device Certificate Registration PIN ID from Support Portal
    vm-series-auto-registration-pin-value = "" # TODO: Insert Device Certificate Registration PIN value from Support Portal
    authcodes                             = "" # TODO: Insert license authorization code from Support Portal
  }
  */

  /* Uncomment the section below to use full bootstrap from Storage Account, make sure to uncomment `bootstrap_storages` section too
  bootstrap_package = {
    bootstrap_storage_key  = "bootstrap"
    static_files           = { "files/init-cfg.txt" = "config/init-cfg.txt" } # TODO: Modify the map key to reflect a path to init-cfg file
    bootstrap_xml_template = "templates/bootstrap-gwlb.tftpl"                 # TODO: Insert a path to bootstrap template file
    data_snet_key          = "data"
  }
  */
}

vmseries = {
  "fw-1" = {
    name     = "firewall01"
    vnet_key = "transit"
    virtual_machine = {
      zone = 1
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
    virtual_machine = {
      zone = 2
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
        frontend_ips = {
          "app1" = {
            name             = "app1-frontend"
            create_public_ip = true
            public_ip_name   = "public-lb-app1-frontend-pip"
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
        frontend_ips = {
          "app2" = {
            name             = "app2-frontend"
            create_public_ip = true
            public_ip_name   = "public-lb-app2-frontend-pip"
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
