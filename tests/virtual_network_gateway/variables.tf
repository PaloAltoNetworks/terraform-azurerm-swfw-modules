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

# NETWORK

variable "vnets" {
  description = <<-EOF
  A map defining VNETs.
  
  For detailed documentation on each property refer to [module documentation](../../modules/vnet/README.md)

  - `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, `false` will source
                                an existing VNET.
  - `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = false` this should be a
                                full resource name, including prefixes.
  - `address_space`           - (`list`, required when `create_virtual_network = false`) a list of CIDRs for a newly created VNET.
  - `dns_servers`             - (`list`, optional, defaults to module defaults) a list of IP addresses of custom DNS servers (by
                                default Azure DNS is used).
  - `resource_group_name`     - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which the
                                VNET will reside or is sourced from.
  - `create_subnets`          - (`bool`, optional, defaults to `true`) if `true`, create Subnets inside the Virtual Network,
                                otherwise use source existing subnets.
  - `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                                [VNET module documentation](../../modules/vnet/README.md#subnets).
  - `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#network_security_groups).
  - `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#route_tables).
  EOF
  type = map(object({
    name                   = string
    resource_group_name    = optional(string)
    create_virtual_network = optional(bool, true)
    address_space          = optional(list(string))
    dns_servers            = optional(list(string))
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
  }))
}

variable "public_ips" {
  description = <<-EOF
  A map defining Public IP Addresses and Prefixes.

  Following properties are available:

  - `public_ip_addresses` - (`map`, optional) map of objects describing Public IP Addresses, please refer to
                            [module documentation](../../modules/public_ip/README.md#public_ip_addresses)
                            for available properties.
  - `public_ip_prefixes`  - (`map`, optional) map of objects describing Public IP Prefixes, please refer to
                            [module documentation](../../modules/public_ip/README.md#public_ip_prefixes)
                            for available properties.
  EOF
  default     = {}
  type = object({
    public_ip_addresses = optional(map(object({
      create                     = bool
      name                       = string
      resource_group_name        = optional(string)
      zones                      = optional(list(string))
      domain_name_label          = optional(string)
      idle_timeout_in_minutes    = optional(number)
      prefix_name                = optional(string)
      prefix_resource_group_name = optional(string)
    })), {})
    public_ip_prefixes = optional(map(object({
      create              = bool
      name                = string
      resource_group_name = optional(string)
      zones               = optional(list(string))
      length              = optional(number)
    })), {})
  })
}

# VIRTUAL NETWORK GATEWAY

variable "virtual_network_gateways" {
  description = "Map of Virtual Network Gateways to create."
  default     = {}
  nullable    = false
  type = map(object({
    name       = string
    vnet_key   = string
    subnet_key = string
    zones      = optional(list(string))
    edge_zone  = optional(string)
    instance_settings = object({
      type          = optional(string)
      vpn_type      = optional(string)
      generation    = optional(string)
      sku           = optional(string)
      active_active = optional(bool)
    })
    ip_configurations = object({
      primary = object({
        name                          = string
        create_public_ip              = optional(bool)
        public_ip_name                = optional(string)
        public_ip_resource_group_name = optional(string)
        public_ip_key                 = optional(string)
        private_ip_address_allocation = optional(string)
      })
      secondary = optional(object({
        name                          = string
        create_public_ip              = optional(bool)
        public_ip_name                = optional(string)
        public_ip_key                 = optional(string)
        private_ip_address_allocation = optional(string)
      }))
    })
    private_ip_address_enabled       = optional(bool)
    default_local_network_gateway_id = optional(string)
    azure_bgp_peer_addresses         = optional(map(string))
    bgp = optional(object({
      enable = optional(bool, false)
      configuration = optional(object({
        asn         = string
        peer_weight = optional(number)
        primary_peering_addresses = object({
          name               = string
          apipa_address_keys = list(string)
          default_addresses  = optional(list(string))
        })
        secondary_peering_addresses = optional(object({
          name               = string
          apipa_address_keys = list(string)
          default_addresses  = optional(list(string))
        }))
      }))
    }))
    local_network_gateways = optional(map(object({
      name = string
      remote_bgp_settings = optional(object({
        asn                 = string
        bgp_peering_address = string
        peer_weight         = optional(number)
      }))
      gateway_address = optional(string)
      address_space   = optional(list(string), [])
      connection = object({
        name = string
        custom_bgp_addresses = optional(object({
          primary_key   = string
          secondary_key = optional(string)
        }))
        ipsec_policies = list(object({
          dh_group         = string
          ike_encryption   = string
          ike_integrity    = string
          ipsec_encryption = string
          ipsec_integrity  = string
          pfs_group        = string
          sa_datasize      = optional(string)
          sa_lifetime      = optional(string)
        }))
        type       = optional(string)
        mode       = optional(string)
        shared_key = optional(string)
      })
    })), {})
    vpn_clients = optional(map(object({
      address_space         = string
      aad_tenant            = optional(string)
      aad_audience          = optional(string)
      aad_issuer            = optional(string)
      root_certificates     = optional(map(string), {})
      revoked_certificates  = optional(map(string), {})
      radius_server_address = optional(string)
      radius_server_secret  = optional(string)
      vpn_client_protocols  = optional(list(string))
      vpn_auth_types        = optional(list(string))
      custom_routes         = optional(map(list(string)))
    })), {})
  }))
}
