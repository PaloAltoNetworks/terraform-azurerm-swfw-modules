# VNG module sample

A sample of using a VNG module with the new variables layout and usage of `optional` keyword.

The `README` is also in new, document-style format.

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0

### Providers

- `azurerm`

### Modules
Name | Version | Source | Description
--- | --- | --- | ---
`vnet` | - | ../../modules/vnet | 
`public_ip` | - | ../../modules/public_ip | 
`vng` | - | ../../modules/virtual_network_gateway | 

### Resources

- `resource_group` (managed)
- `resource_group` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`resource_group_name`](#resource_group_name) | `string` | Name of the Resource Group.
[`region`](#region) | `string` | The Azure region to use.
[`vnets`](#vnets) | `map` | A map defining VNETs.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`name_prefix`](#name_prefix) | `string` | A prefix that will be added to all created resources.
[`create_resource_group`](#create_resource_group) | `bool` | When set to `true` it will cause a Resource Group creation.
[`tags`](#tags) | `map` | Map of tags to assign to the created resources.
[`public_ips`](#public_ips) | `object` | A map defining Public IP Addresses and Prefixes.
[`virtual_network_gateways`](#virtual_network_gateways) | `map` | Map of Virtual Network Gateways to create.

### Outputs

Name |  Description
--- | ---
`vng_public_ips` | IP Addresses of the VNGs.
`vng_ipsec_policy` | IPsec policy used for Virtual Network Gateway connection

### Required Inputs details

#### resource_group_name

Name of the Resource Group.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### region

The Azure region to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### vnets

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


Type: 

```hcl
map(object({
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
```


<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### name_prefix

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


Type: string

Default value: ``

<sup>[back to list](#modules-optional-inputs)</sup>

#### create_resource_group

When set to `true` it will cause a Resource Group creation.
Name of the newly specified RG is controlled by `resource_group_name`.
  
When set to `false` the `resource_group_name` parameter is used to specify a name of an existing Resource Group.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### tags

Map of tags to assign to the created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### public_ips

A map defining Public IP Addresses and Prefixes.

Following properties are available:

- `public_ip_addresses` - (`map`, optional) map of objects describing Public IP Addresses, please refer to
                          [module documentation](../../modules/public_ip/README.md#public_ip_addresses)
                          for available properties.
- `public_ip_prefixes`  - (`map`, optional) map of objects describing Public IP Prefixes, please refer to
                          [module documentation](../../modules/public_ip/README.md#public_ip_prefixes)
                          for available properties.


Type: 

```hcl
object({
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
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_network_gateways

Map of Virtual Network Gateways to create.

Type: 

```hcl
map(object({
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
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
