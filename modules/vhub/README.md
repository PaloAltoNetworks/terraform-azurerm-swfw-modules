# Palo Alto Networks vHub Module for Azure

A Terraform module for deploying a Virtual Hub (vHub) and its components required for the firewalls in Azure.

## Usage

This module is designed to work in several *modes* depending on which variables or flags are set. Most common usage scenarios are:

- create all - creates a  vHub, Connections and Route Tables. In this mode a vHub is created. The Connections and Route Tables are assigned to the vHub:

  ```hcl
    virtual_hubs = {
      "virtual_hub" = {
        name           = "virtual_hub"
        address_prefix = "11.0.0.0/24"
        connections = {
          "panorama-to-hub" = { # TODO: Specify your existing panorama vnet!
            name                       = "panorama-to-hub"
            connection_type            = "Vnet"
            remote_virtual_network_key = "panorama"
          }
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
        route_tables = {
          "default" = {
            name   = "default-rt"
            labels = ["default-rt"]
          }
        }

      }
    }
  ```

- sources a vHub but creates Connections and Route Tables:

  ```hcl
    virtual_hubs = {
      "virtual_hub" = {
        create              = false
        name                = "virtual_hub"
        resource_group_name = "virtual_wan_rg"
        connections = {
          "panorama-to-hub" = { # TODO: Specify your existing panorama vnet!
            name                       = "panorama-to-hub"
            connection_type            = "Vnet"
            remote_virtual_network_key = "panorama"
          }
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
        route_tables = {
          "default" = {
            name   = "default-rt"
            labels = ["default-rt"]
          }
        }
      }
    }
  ```

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 4.0

### Providers

- `azurerm`, version: ~> 4.0



### Resources

- `virtual_hub` (managed)
- `virtual_hub_connection` (managed)
- `virtual_hub_route_table` (managed)
- `vpn_gateway` (managed)
- `vpn_gateway_connection` (managed)
- `vpn_site` (managed)
- `virtual_hub` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`virtual_hub_name`](#virtual_hub_name) | `string` | The name of the Azure Virtual Hub.
[`virtual_wan_id`](#virtual_wan_id) | `string` | The ID of Virtual WAN.
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group where the Virtual Hub should exist.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`allow_branch_to_branch_traffic`](#allow_branch_to_branch_traffic) | `bool` | Optional boolean flag to specify whether branch-to-branch traffic is allowed.
[`disable_vpn_encryption`](#disable_vpn_encryption) | `bool` | Optional boolean flag to specify whether VPN encryption is disabled.
[`create_virtual_hub`](#create_virtual_hub) | `bool` | Controls Virtual Hub creation.
[`region`](#region) | `string` | The name of the Azure region to deploy virtual Hub.
[`virtual_hub_address_prefix`](#virtual_hub_address_prefix) | `string` | The address prefix for the Virtual Hub.
[`hub_routing_preference`](#hub_routing_preference) | `string` | Virtual Hub routing preference.
[`connections`](#connections) | `map` | Map of objects describing connections within a Virtual Hub.
[`route_tables`](#route_tables) | `map` | Map of objects describing route tables to manage within a Virtual Hub.
[`vpn_gateway`](#vpn_gateway) | `object` | Object describing a VPN Gateway to be managed within a Virtual Hub.
[`vpn_sites`](#vpn_sites) | `map` | Map of objects describing VPN sites to be configured within the Azure environment.

### Outputs

Name |  Description
--- | ---
`virtual_hub_id` | The identifier of the created or sourced Virtual HUB.
`route_table_ids` | A map of identifiers for the created Route Tables.

### Required Inputs details

#### virtual_hub_name

The name of the Azure Virtual Hub.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### virtual_wan_id

The ID of Virtual WAN

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### resource_group_name

The name of the Resource Group where the Virtual Hub should exist.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### allow_branch_to_branch_traffic

Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### disable_vpn_encryption

Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false.

Type: bool

Default value: `false`

<sup>[back to list](#modules-optional-inputs)</sup>

#### create_virtual_hub

Controls Virtual Hub creation. When set to `true`, creates the Virtual Hub, otherwise just uses a pre-existing Virtual Hub.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### region

The name of the Azure region to deploy virtual Hub

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_hub_address_prefix

The address prefix for the Virtual Hub. Must be a subnet no smaller than /24 (Microsoft recommends /23)

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### hub_routing_preference

Virtual Hub routing preference. Acceptable values are `ExpressRoute`, `ASPath` and `VpnGateway`.

Type: string

Default value: `ExpressRoute`

<sup>[back to list](#modules-optional-inputs)</sup>

#### connections

Map of objects describing connections within a Virtual Hub.

Each object represents one connection, and supports the following properties:

- `name`                       - (`string`, required) the name of the connection. Must be unique within the Virtual Hub.
- `connection_type`            - (`string`, required) the type of connection. Use `Vnet` for Virtual Network connections.
- `remote_virtual_network_id`  - (`string`, optional) the resource ID of a remote Virtual Network.
- `virtual_Hub_key`            - (`string`, required) the key referencing the Virtual Hub.
- `vpn_site_key`               - (`string`, optional) the key referencing the VPN site used in this connection.
- `vpn_link`                   - (`list`, optional, defaults to `[]`) list of VPN link configurations. Each object supports:
  - `vpn_link_name`                  - (`string`, required) the name of the VPN link.
  - `vpn_site_link_key`              - (`string`, required) the key referencing the VPN site link.
  - `bandwidth_mbps`                 - (`number`, optional, defaults to `10`) bandwidth limit in Mbps.
  - `bgp_enabled`                    - (`bool`, optional, defaults to `false`) enables BGP on this link.
  - `connection_mode`                - (`string`, optional, defaults to `Default`) valid values: `Default`, `InitiatorOnly`, `ResponderOnly`.
  - `protocol`                       - (`string`, optional, defaults to `IKEv2`) valid values: `IKEv2`, `IKEv1`.
  - `ratelimit_enabled`              - (`bool`, optional, defaults to `false`) enables rate limiting.
  - `route_weight`                   - (`number`, optional, defaults to `0`) routing weight for this link.
  - `shared_key`                     - (`string`, optional) pre-shared key for the VPN.
  - `local_azure_ip_address_enabled` - (`bool`, optional, defaults to `false`) enables use of local Azure IP address.
  - `ipsec_policy`                   - (`object`, optional) IPSec policy configuration. Supports:
    - `dh_group`                 - (`string`, optional) valid values: `DHGroup14`, `DHGroup24`, `ECP256`, `ECP384`.
    - `ike_encryption_algorithm` - (`string`, optional) valid values: `AES128`, `AES256`, `GCMAES128`, `GCMAES256`.
    - `ike_integrity_algorithm`  - (`string`, optional) valid values: `SHA256`, `SHA384`.
    - `encryption_algorithm`     - (`string`, optional) valid values: `AES192`, `AES128`, `AES256`, `DES`, `DES3`, `GCMAES192`, `GCMAES128`, `GCMAES256`, `None`.
    - `integrity_algorithm`      - (`string`, optional) valid values: `SHA256`, `GCMAES128`, `GCMAES256`.
    - `pfs_group`                - (`string`, optional) valid values: `ECP384`, `ECP256`, `PFSMM`, `PFS1`, `PFS14`, `PFS2`, `PFS24`, `PFS2048`, `None`.
    - `sa_data_size_kb`          - (`number`, optional) value must be `0` or between `1024` and `2147483647`.
    - `sa_lifetime_sec`          - (`number`, optional) lifetime in seconds.

- `routing`                    - (`object`, optional) routing configuration. Supports:
  - `associated_route_table_key`                - (`string`, optional) key of the associated route table.
  - `propagated_route_table_keys`               - (`list(string)`, optional) list of route table keys to propagate routes to.
  - `propagated_route_table_labels`             - (`set(string)`, optional) set of labels for propagated route tables.
  - `static_vnet_route_name`                    - (`string`, optional) name of the static route.
  - `static_vnet_route_address_prefixes`        - (`set(string)`, optional) set of CIDR address prefixes for static route.
  - `static_vnet_route_next_hop_ip_address`     - (`string`, optional) IP address of the next hop.
  - `static_vnet_local_route_override_criteria` - (`string`, optional, defaults to `Contains`) valid values: `Contains`, `Equal`.


Type: 

```hcl
map(object({
    name                      = string
    connection_type           = string
    remote_virtual_network_id = optional(string)
    vpn_site_key              = optional(string)
    vpn_link = optional(list(object({
      vpn_link_name                  = string
      vpn_site_link_key              = string
      bandwidth_mbps                 = optional(number, 10)
      bgp_enabled                    = optional(bool, false)
      connection_mode                = optional(string, "Default")
      protocol                       = optional(string, "IKEv2")
      ratelimit_enabled              = optional(bool, false)
      route_weight                   = optional(number, 0)
      shared_key                     = optional(string)
      local_azure_ip_address_enabled = optional(bool, false)
      ipsec_policy = optional(object({
        dh_group                 = optional(string)
        ike_encryption_algorithm = optional(string)
        ike_integrity_algorithm  = optional(string)
        encryption_algorithm     = optional(string)
        integrity_algorithm      = optional(string)
        pfs_group                = optional(string)
        sa_data_size_kb          = optional(number)
        sa_lifetime_sec          = optional(number)
      }))
    })), [])
    routing = optional(object({
      associated_route_table_key                = optional(string)
      propagated_route_table_keys               = optional(list(string))
      propagated_route_table_labels             = optional(set(string))
      static_vnet_route_name                    = optional(string)
      static_vnet_route_address_prefixes        = optional(set(string))
      static_vnet_route_next_hop_ip_address     = optional(string)
      static_vnet_local_route_override_criteria = optional(string)
    }))
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### route_tables

Map of objects describing route tables to manage within a Virtual Hub.

Each entry defines a Virtual Hub Route Table configuration with attributes to control its association.

List of available attributes for each route table entry:

- `name`                - (`string`, required) name of the Virtual Hub Route Table.
- `labels`              - (`set`, optional) Set of labels associated with the Route Table.


Type: 

```hcl
map(object({
    name   = string
    labels = optional(set(string))
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vpn_gateway

Object describing a VPN Gateway to be managed within a Virtual Hub.

List of available attributes:

- `name`                - (`string`, required) name of the VPN Gateway.
- `resource_group_name` - (`string`, optional) name of the Resource Group where the VPN Gateway should be created.
- `scale_unit`          - (`number`, optional) specifies the scale unit for the VPN Gateway, impacting its performance and 
                          throughput. Defaults to `1`.
- `routing_preference`  - (`string`, optional) specifies the routing preference. Valid values are `Microsoft Network` and
                          `Internet`.


Type: 

```hcl
object({
    name                = string
    resource_group_name = optional(string)
    scale_unit          = optional(number, 1)
    routing_preference  = optional(string, "Microsoft Network")
  })
```


Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vpn_sites

Map of objects describing VPN sites to be configured within the Azure environment.

Each object defines a single VPN site and supports the following properties:

- `name`                 - (`string`, required) the unique name of the VPN site.
- `resource_group_name`  - (`string`, optional) the name of the resource group for the VPN site.
- `region`               - (`string`, optional) the Azure region where the site is located.
- `address_cidrs`        - (`set(string)`, required) set of IPv4 CIDR blocks associated with the site.

- `link`                 - (`list(object)`, optional, defaults to `[]`) list of individual link configurations. Each object supports:
  - `name`                  - (`string`, required) the name of the link.
  - `ip_address`            - (`string`, optional) the public IP address of the link.
  - `fqdn`                  - (`string`, optional) the fully qualified domain name for the link.
  - `provider_name`         - (`string`, optional) the name of the service provider.
  - `speed_in_mbps`         - (`number`, optional, defaults to `0`) the link speed in Mbps.


Type: 

```hcl
map(object({
    name                = string
    resource_group_name = optional(string)
    region              = optional(string)
    address_cidrs       = optional(set(string))
    link = optional(map(object({
      name          = string
      ip_address    = optional(string)
      fqdn          = optional(string)
      provider_name = optional(string)
      speed_in_mbps = optional(number, 0)
    })), {})
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
