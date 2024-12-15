# GENERAL
variable "subscription_id" {
  description = <<-EOF
  Azure Subscription ID is a required argument since AzureRM provider v4.

  **Note!** \
  Instead of putting the Subscription ID directly in the code, it's recommended to use an environment variable. Create an
  environment variable named `ARM_SUBSCRIPTION_ID` with your Subscription ID as value and leave this variable set to `null`.
  EOF
  type        = string
}

variable "name_prefix" {
  description = <<-EOF
  A prefix that will be added to all created resources.
  There is no default delimiter applied between the prefix and the resource name.
  Please include the delimiter in the actual prefix.

  Example:
  ```
  name_prefix = "test-"
  ```

  **Note!** \
  This prefix is not applied to existing resources. If you plan to reuse i.e. a VNET please specify it's full name,
  even if it is also prefixed with the same value as the one in this property.
  EOF
  default     = ""
  type        = string
}

variable "create_resource_group" {
  description = <<-EOF
  When set to `true` it will cause a Resource Group creation.
  Name of the newly specified RG is controlled by `resource_group_name`.

  When set to `false` the `resource_group_name` parameter is used to specify a name of an existing Resource Group.
  EOF
  default     = true
  type        = bool
}

variable "resource_group_name" {
  description = "Name of the Resource Group."
  type        = string
}

variable "region" {
  description = "The Azure region to use."
  type        = string
}

variable "tags" {
  description = "Map of tags to assign to the created resources."
  default     = {}
  type        = map(string)
}

#NETWORK

variable "vnets" {
  description = <<-EOF
  A map defining VNETs.

  For detailed documentation on each property refer to [module documentation](../../modules/vnet/README.md)

  - `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, `false` will source
                                an existing VNET.
  - `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = false` this should be a
                                full resource name, including prefixes.
  - `resource_group_name`     - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which the
                                VNET will reside or is sourced from.
  - `address_space`           - (`list`, required when `create_virtual_network = false`) a list of CIDRs for a newly created VNET.
  - `dns_servers`             - (`list`, optional, defaults to module defaults) a list of IP addresses of custom DNS servers (by
                                default Azure DNS is used).
  - `vnet_encryption`         - (`string`, optional, defaults to module default) enables Azure Virtual Network Encryption when
                                set, only possible value at the moment is `AllowUnencrypted`. When set to `null`, the feature is 
                                disabled.
  - `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#network_security_groups).
  - `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#route_tables).
  - `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                                [VNET module documentation](../../modules/vnet/README.md#subnets).
  EOF
  type = map(object({
    create_virtual_network = optional(bool, true)
    name                   = string
    resource_group_name    = optional(string)
    address_space          = optional(list(string))
    dns_servers            = optional(list(string))
    vnet_encryption        = optional(string)
    network_security_groups = optional(map(object({
      name = string
      rules = optional(map(object({
        name                         = string
        priority                     = number
        direction                    = string
        access                       = string
        protocol                     = string
        source_port_range            = optional(string)
        source_port_ranges           = optional(list(string))
        destination_port_range       = optional(string)
        destination_port_ranges      = optional(list(string))
        source_address_prefix        = optional(string)
        source_address_prefixes      = optional(list(string))
        destination_address_prefix   = optional(string)
        destination_address_prefixes = optional(list(string))
      })), {})
    })), {})
    route_tables = optional(map(object({
      name                          = string
      bgp_route_propagation_enabled = optional(bool)
      routes = map(object({
        name                = string
        address_prefix      = string
        next_hop_type       = string
        next_hop_ip_address = optional(string)
      }))
    })), {})
    subnets = optional(map(object({
      create                          = optional(bool, true)
      name                            = string
      address_prefixes                = optional(list(string), [])
      network_security_group_key      = optional(string)
      route_table_key                 = optional(string)
      enable_storage_service_endpoint = optional(bool)
      enable_cloudngfw_delegation     = optional(bool)
    })), {})
  }))
}

#VIRTUAL WAN

variable "virtual_wans" {
  description = <<-EOF
  A map defining VIRTUAL_WANs.

  For detailed documentation on each property refer to [module documentation](../../modules/virtual_wan/README.md)

  - `create_virtual_wan`                - (`bool`, optional, defaults to `true`) when set to `true` will create a VIRTUAL WAN, `false` will source
                                        an existing VIRTUAL WAN.
  - `name`                              - (`string`, required) a name of a VIRTUAL WAN. In case `create_virtual_wan = false` this should be a
                                        full resource name, including prefixes.
  - `resource_group_name`               - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which the
                                        VIRTUAL WAN will reside or is sourced from.
  - `disable_vpn_encryption`            - (`bool`, optional, defaults to `false`) if `true`, VPN encryption is disabled.
  - `allow_branch_to_branch_traffic`    - (`bool`, optional, defaults to `true`) if `false`, branch-to-branch traffic is not allowed.
  - `office365_local_breakout_category` - (`string`, optional, defaults to `None`) Specifies the Office365 local breakout category. Possible values are: Optimize, OptimizeAndAllow, All, None.
  - `virtual_wan_type`                  - (`string`, optional, defaults to `Standard`) Specifies the Virtual WAN type. Possible values are: Basic, Standard.
  EOF
  type = map(object({
    name                           = string
    resource_group_name            = optional(string)
    create_virtual_wan             = optional(bool, true)
    disable_vpn_encryption         = optional(bool, false)
    allow_branch_to_branch_traffic = optional(bool, true)
    virtual_wan_type               = optional(string)
    virtual_hubs = optional(map(object({
      name                   = string
      address_prefix         = optional(string) #required during creation
      create_virtual_hub     = optional(bool, true)
      resource_group_name    = optional(string) #required during import
      region                 = optional(string)
      hub_routing_preference = optional(string)
      tags                   = optional(map(string))
    })), {})
    connections = optional(map(object({
      name                       = string
      connection_type            = string
      virtual_hub_key            = optional(string)
      remote_virtual_network_key = optional(string)
      vpn_gateway_key            = optional(string)
      vpn_site_key               = optional(string)
      vpn_link = optional(list(object({
        vpn_link_name                  = string
        vpn_site_link_index            = number
        bandwidth_mbps                 = optional(number)
        bgp_enabled                    = optional(bool)
        connection_mode                = optional(string)
        protocol                       = optional(string)
        ratelimit_enabled              = optional(bool)
        shared_key                     = optional(string)
        local_azure_ip_address_enabled = optional(bool)
        ipsec_policy = optional(object({
          dh_group                 = string
          ike_encryption_algorithm = string
          ike_integrity_algorithm  = string
          encryption_algorithm     = string
          integrity_algorithm      = string
          pfs_group                = string
          sa_data_size_kb          = number
          sa_lifetime_sec          = number
        }))
      })))
      routing = optional(object({
        associated_route_table_key                = optional(string)
        propagated_route_table_keys               = optional(list(string))
        propagated_route_table_labels             = optional(set(string))
        static_vnet_route_name                    = optional(string)
        static_vnet_route_address_prefixes        = optional(set(string))
        static_vnet_route_next_hop_ip_address     = optional(string)
        static_vnet_local_route_override_criteria = optional(string)
      }))
    })), {})
    vpn_sites = optional(map(object({
      name                = string
      location            = optional(string)
      resource_group_name = optional(string)
      address_cidrs       = optional(set(string))
      link = optional(list(object({
        name          = string
        ip_address    = optional(string)
        fqdn          = optional(string) #albo ip albo fqdn
        provider_name = optional(string)
        speed_in_mbps = optional(number, 0)
      })))
    })), {})
    vpn_gateways = optional(map(object({
      name                = string
      location            = optional(string)
      resource_group_name = optional(string)
      virtual_hub_key     = string
      scale_unit          = optional(number)
      routing_preference  = optional(string)
      tags                = optional(map(string))
    })), {})
    route_tables = optional(map(object({
      create_route_table  = string
      name                = string
      virtual_hub_key     = optional(string)
      labels              = optional(set(string))
      virtual_hub_name    = optional(string)
      resource_group_name = optional(string)
    })), {})
  }))
}

#CNGFW
variable "cngfws" {
  type = map(object({
    attachment_type      = string
    management_mode      = string
    virtual_hub_key      = optional(string)
    virtual_wan_key      = optional(string)
    virtual_network_key  = optional(string)
    trusted_subnet_key   = optional(string)
    untrusted_subnet_key = optional(string)
    palo_alto_virtual_appliance = map(object({
      palo_alto_virtual_appliance_name = string
    }))
    cngfw_config = object({
      cngfw_name                      = string
      create_public_ip                = optional(bool)
      public_ip_name                  = string
      public_ip_resource_group_name   = optional(string)
      palo_alto_virtual_appliance_key = string
      panorama_base64_config          = optional(string)
      destination_nat = optional(map(object({
        destination_nat_name      = string
        destination_nat_protocol  = string
        frontend_port             = number
        backend_port              = number
        backend_public_ip_address = string
      })), {})
    })
    }
  ))
}

variable "virtual_hub_routing" {
  type = object({
    advanced_routing = optional(bool, false)
    virtual_wan_key  = string
    cngfw_key        = string
    routing_intent = optional(object({
      routing_intent_name = string
      virtual_hub_key     = string
      routing_policy = list(object({
        routing_policy_name = string
        destinations        = list(string)
        next_hop_key        = string
      }))
    }))
    routes = optional(list(object({
      route_name        = string
      destinations_type = string
      destinations      = set(string)
      next_hop_type     = string
      nex_hop_key       = string
      route_table_key   = string
    })))
  })
}



# TEST INFRASTRUCTURE

variable "test_infrastructure" {
  description = <<-EOF
  A map defining test infrastructure including test VMs and Azure Bastion hosts.

  For details and defaults for available options please refer to the
  [`test_infrastructure`](../../modules/test_infrastructure/README.md) module.

  Following properties are supported:

  - `create_resource_group`  - (`bool`, optional, defaults to `true`) when set to `true`, a new Resource Group is created. When
                               set to `false`, an existing Resource Group is sourced.
  - `resource_group_name`    - (`string`, optional) name of the Resource Group to be created or sourced.
  - `vnets`                  - (`map`, required) a map defining VNETs and peerings for the test environment. The most basic
                               properties are as follows:

    - `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET,
                                  `false` will source an existing VNET.
    - `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = `false` this should be
                                  a full resource name, including prefixes.
    - `address_space`           - (`list(string)`, required when `create_virtual_network = `false`) a list of CIDRs for a newly
                                  created VNET.
    - `create_subnets`          - (`bool`, optional, defaults to `true`) if `true`, create Subnets inside the Virtual Network,
                                  otherwise use source existing subnets.
    - `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                                  [VNET module documentation](../../modules/vnet/README.md#subnets).
    - `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                                  [VNET module documentation](../../modules/vnet/README.md#network_security_groups).
    - `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                                  [VNET module documentation](../../modules/vnet/README.md#route_tables).
    - `local_peer_config`       - (`map`, optional) a map that contains local peer configuration parameters. This value allows to 
                                  set `allow_virtual_network_access`, `allow_forwarded_traffic`, `allow_gateway_transit` and 
                                  `use_remote_gateways` parameters on the local VNet peering. 
    - `remote_peer_config`      - (`map`, optional) a map that contains remote peer configuration parameters. This value allows to
                                  set `allow_virtual_network_access`, `allow_forwarded_traffic`, `allow_gateway_transit` and 
                                  `use_remote_gateways` parameters on the remote VNet peering.  

    For all properties and their default values see [module's documentation](../../modules/test_infrastructure/README.md#vnets).

  - `load_balancers`         - (`map`, optional) a map containing configuration for all (both private and public) Load Balancers.
                               The most basic properties are as follows:

    - `name`                    - (`string`, required) a name of the Load Balancer.
    - `vnet_key`                - (`string`, optional, defaults to `null`) a key pointing to a VNET definition in the `var.vnets`
                                  map that stores the Subnet described by `subnet_key`.
    - `zones`                   - (`list`, optional, defaults to module default) a list of zones for Load Balancer's frontend IP
                                  configurations.
    - `backend_name`            - (`string`, optional) a name of the backend pool to create.
    - `health_probes`           - (`map`, optional, defaults to `null`) a map defining health probes that will be used by load
                                  balancing rules, please refer to
                                  [loadbalancer module documentation](../../modules/loadbalancer/README.md#health_probes) for
                                  more specific use cases and available properties.
    - `nsg_auto_rules_settings` - (`map`, optional, defaults to `null`) a map defining a location of an existing NSG rule that
                                  will be populated with `Allow` rules for each load balancing rule (`in_rules`), please refer to
                                  [loadbalancer module documentation](../../modules/loadbalancer/README.md#nsg_auto_rules_settings)
                                  for available properties.

    Please note that in this example two additional properties are available:

      - `nsg_vnet_key` - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to a VNET definition in the
                         `var.vnets` map that stores the NSG described by `nsg_key`.
      - `nsg_key`      - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to an NSG definition in the
                         `var.vnets` map.

    - `frontend_ips`            - (`map`, optional, defaults to `{}`) a map containing frontend IP configuration with respective
                                  `in_rules` and `out_rules`, please refer to
                                  [loadbalancer module documentation](../../modules/loadbalancer/README.md#frontend_ips) for
                                  available properties.

      **Note!** \
      In this example the `subnet_id` is not available directly, another property has been introduced instead:

      - `subnet_key` - (`string`, optional, defaults to `null`) a key pointing to a Subnet definition in the `var.vnets` map.

    For all properties and their default values see
    [module's documentation](../../modules/test_infrastructure/README.md#load_balancers).

  - `authentication`         - (`map`, optional, defaults to example defaults) authentication settings for the deployed VMs.
  - `spoke_vms`              - (`map`, required) a map defining test VMs. The most basic properties are as follows:

    - `name`              - (`string`, required) a name of the VM.
    - `vnet_key`          - (`string`, required) a key describing a VNET defined in `vnets` property.
    - `subnet_key`        - (`string`, required) a key describing a Subnet found in a VNET definition.
    - `load_balancer_key` - (`string`, optional) a key describing a Load Balancer defined in `load_balancers` property.

    For all properties and their default values see
    [module's documentation](../../modules/test_infrastructure/README.md#test_vms).

  - `bastions`               - (`map`, required) a map containing Azure Bastion definitions. The most basic properties are as
                               follows:

    - `name`       - (`string`, required) an Azure Bastion name.
    - `vnet_key`   - (`string`, required) a key describing a VNET defined in `vnets` property. This VNET should already have an
                     existing subnet called `AzureBastionSubnet` (the name is hardcoded by Microsoft).
    - `subnet_key` - (`string`, required) a key pointing to a Subnet dedicated to a Bastion deployment.

    For all properties and their default values see
    [module's documentation](../../modules/test_infrastructure/README.md#bastions).
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    create_resource_group = optional(bool, true)
    resource_group_name   = optional(string)
    vnets = map(object({
      name                    = string
      create_virtual_network  = optional(bool, true)
      address_space           = optional(list(string))
      hub_resource_group_name = optional(string)
      hub_vnet_name           = optional(string)
      network_security_groups = optional(map(object({
        name = string
        rules = optional(map(object({
          name                         = string
          priority                     = number
          direction                    = string
          access                       = string
          protocol                     = string
          source_port_range            = optional(string)
          source_port_ranges           = optional(list(string))
          destination_port_range       = optional(string)
          destination_port_ranges      = optional(list(string))
          source_address_prefix        = optional(string)
          source_address_prefixes      = optional(list(string))
          destination_address_prefix   = optional(string)
          destination_address_prefixes = optional(list(string))
        })), {})
      })), {})
      route_tables = optional(map(object({
        name                          = string
        disable_bgp_route_propagation = optional(bool)
        routes = map(object({
          name                = string
          address_prefix      = string
          next_hop_type       = string
          next_hop_ip_address = optional(string)
        }))
      })), {})
      create_subnets = optional(bool, true)
      subnets = optional(map(object({
        name                            = string
        address_prefixes                = optional(list(string), [])
        network_security_group_key      = optional(string)
        route_table_key                 = optional(string)
        enable_storage_service_endpoint = optional(bool, false)
      })), {})
      local_peer_config = optional(object({
        allow_virtual_network_access = optional(bool, true)
        allow_forwarded_traffic      = optional(bool, true)
        allow_gateway_transit        = optional(bool, false)
        use_remote_gateways          = optional(bool, false)
      }), {})
      remote_peer_config = optional(object({
        allow_virtual_network_access = optional(bool, true)
        allow_forwarded_traffic      = optional(bool, true)
        allow_gateway_transit        = optional(bool, false)
        use_remote_gateways          = optional(bool, false)
      }), {})
    }))
    load_balancers = optional(map(object({
      name         = string
      vnet_key     = optional(string)
      zones        = optional(list(string))
      backend_name = optional(string)
      health_probes = optional(map(object({
        name                = string
        protocol            = string
        port                = optional(number)
        probe_threshold     = optional(number)
        interval_in_seconds = optional(number)
        request_path        = optional(string)
      })))
      nsg_auto_rules_settings = optional(object({
        nsg_name                = optional(string)
        nsg_vnet_key            = optional(string)
        nsg_key                 = optional(string)
        nsg_resource_group_name = optional(string)
        source_ips              = list(string)
        base_priority           = optional(number)
      }))
      frontend_ips = optional(map(object({
        name                          = string
        subnet_key                    = optional(string)
        create_public_ip              = optional(bool, false)
        public_ip_name                = optional(string)
        public_ip_resource_group_name = optional(string)
        public_ip_key                 = optional(string)
        public_ip_prefix_key          = optional(string)
        private_ip_address            = optional(string)
        gwlb_key                      = optional(string)
        in_rules = optional(map(object({
          name                = string
          protocol            = string
          port                = number
          backend_port        = optional(number)
          health_probe_key    = optional(string)
          floating_ip         = optional(bool)
          session_persistence = optional(string)
          nsg_priority        = optional(number)
        })), {})
        out_rules = optional(map(object({
          name                     = string
          protocol                 = string
          allocated_outbound_ports = optional(number)
          enable_tcp_reset         = optional(bool)
          idle_timeout_in_minutes  = optional(number)
        })), {})
      })), {})
    })), {})
    authentication = optional(object({
      username = optional(string, "bitnami")
      password = optional(string)
    }), {})
    spoke_vms = map(object({
      name               = string
      interface_name     = optional(string)
      disk_name          = optional(string)
      vnet_key           = string
      subnet_key         = string
      load_balancer_key  = optional(string)
      private_ip_address = optional(string)
      size               = optional(string)
      image = optional(object({
        publisher               = optional(string)
        offer                   = optional(string)
        sku                     = optional(string)
        version                 = optional(string)
        enable_marketplace_plan = optional(bool)
      }), {})
      custom_data = optional(string)
    }))
    bastions = map(object({
      name                          = string
      create_public_ip              = optional(bool, true)
      public_ip_name                = optional(string)
      public_ip_resource_group_name = optional(string)
      public_ip_key                 = optional(string)
      vnet_key                      = string
      subnet_key                    = string
    }))
  }))
}