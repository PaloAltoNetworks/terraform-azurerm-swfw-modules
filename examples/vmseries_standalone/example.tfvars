# GENERAL

subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "North Europe"
resource_group_name = "vmseries-standalone"
name_prefix         = "example-"
tags = {
  "createdBy"     = "Palo Alto Networks"
  "createdWith"   = "Terraform"
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
    }
    subnets = {
      "management" = {
        name                       = "mgmt-snet"
        address_prefixes           = ["10.0.0.0/28"]
        network_security_group_key = "management"
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

# VM-SERIES

/* Uncomment the section below to create a Storage Account for full bootstrap if you intend to use this bootstrap method
bootstrap_storages = {
  "bootstrap" = {
    name = "smplngfwbtstrp" # TODO: Change the Storage Account name to be globally unique
    storage_network_security = {
      vnet_key            = "transit"
      allowed_subnet_keys = ["management"]
      allowed_public_ips  = ["1.1.1.1/30"] # TODO: Whitelist public IP addresses that will be used to access storage account
    }
  }
}
*/

vmseries = {
  "fw-1" = {
    name     = "firewall01"
    vnet_key = "transit"
    image = {
      version = "11.1.607"
    }
    virtual_machine = {
      zone = null

      # This example uses basic user-data bootstrap method by default, comment out the map below if you want to use another one
      bootstrap_options = {
        type               = "dhcp-client"
        plugin-op-commands = "advance-routing:enable"
      }

      /* Uncomment the section below to use Panorama Software Firewall License (sw_fw_license) plugin bootstrap and fill out missing data
      bootstrap_options = {
        type               = "dhcp-client"
        plugin-op-commands = "advance-routing:enable,panorama-licensing-mode-on"
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
      }
      */
    }
    interfaces = [
      {
        name             = "vm-mgmt"
        subnet_key       = "management"
        create_public_ip = true
      }
    ]
  }
}
