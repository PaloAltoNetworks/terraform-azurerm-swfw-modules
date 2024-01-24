# --- GENERAL --- #
location            = "North Europe"
resource_group_name = "gwlb"
name_prefix         = "example-"
tags = {
  "CreatedBy"   = "Palo Alto Networks"
  "CreatedWith" = "Terraform"
}

# --- VNET PART --- #
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
            source_address_prefixes    = ["134.238.135.14", "134.238.135.140"]
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
  "app1" = {
    name          = "app1"
    address_space = ["10.0.2.0/25"]
    network_security_groups = {
      "application_inbound" = {
        name = "application-inbound-nsg"
        rules = {
          app_inbound = {
            name                       = "application-allow-inbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefixes    = ["134.238.135.14", "134.238.135.140"]
            source_port_range          = "*"
            destination_address_prefix = "*"
            destination_port_ranges    = ["22", "80", "443"]
          }
        }
      }
    }
    subnets = {
      "app1" = {
        name                       = "app1-snet"
        address_prefixes           = ["10.0.2.0/28"]
        network_security_group_key = "application_inbound"
      }
    }
  }
}


# --- LOAD BALANCING PART --- #
load_balancers = {
  "app1" = {
    name = "app1-lb"
    nsg_auto_rules_settings = {
      nsg_vnet_key = "app1"
      nsg_key      = "application_inbound"
      source_ips   = ["0.0.0.0/0"]
    }
    frontend_ips = {
      "app1" = {
        name             = "app1"
        public_ip_name   = "public-lb-app1-pip"
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

# --- GWLB PART --- #
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

# --- VMSERIES PART --- #
bootstrap_storages = {
  "bootstrap" = {
    name = "examplegwlbbootstrap"
    storage_network_security = {
      vnet_key            = "transit"
      allowed_subnet_keys = ["management"]
      allowed_public_ips  = ["134.238.135.14", "134.238.135.140"]
    }
  }
}

vmseries = {
  "fw-1" = {
    name = "firewall01"
    image = {
      version = "10.2.3"
    }
    virtual_machine = {
      vnet_key = "transit"
      size     = "Standard_DS3_v2"
      zone     = 1
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
    name = "firewall02"
    image = {
      version = "10.2.3"
    }
    virtual_machine = {
      vnet_key = "transit"
      size     = "Standard_DS3_v2"
      zone     = 2
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


appvms = {
  app1vm01 = {
    name              = "app1-vm01"
    avzone            = "3"
    vnet_key          = "app1"
    subnet_key        = "app1"
    load_balancer_key = "app1"
    username          = "appadmin"
    custom_data       = <<SCRIPT
#!/bin/sh
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Backend VM is $(hostname)" | sudo tee /var/www/html/index.html
SCRIPT
  }
}