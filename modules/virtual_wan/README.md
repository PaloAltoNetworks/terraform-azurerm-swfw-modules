# Palo Alto Networks VWan Module for Azure

A Terraform module for deploying a Virtual Wan (VWan) and its components required for the firewalls in Azure.

## Usage

This module is designed to work in several *modes* depending on which variables or flags are set. Most common usage scenarios are:

- create all -  creates a VWan, Hub, Connections and Route Tables. In this mode, a VWAN and Hub are created. The connections and route tables are assigned to the Hub:

  ```hcl
virtual_wans = {
  "virtual_wan" = {
    name = "virtual_wan"
    virtual_hubs = {
      "virtual_hub" = {
        name           = "virtual_hub"
        address_prefix = "11.0.0.0/24"
      }
    }
    connections = {
      "app1-to-hub" = {
        name                       = "app1-to-hub"
        connection_type            = "Vnet"
        virtual_hub_key            = "virtual_hub"
        remote_virtual_network_key = "app1"
      }
   route_tables = {
      "route_table01" = {
        name            = "route_table01"
        virtual_hub_key = "virtual_hub"
        labels          = ["route_table01"]
      }
     }
    }
  }
}
  ```

- source a VWan and HUB but create Connections and Route Tables:

  ```hcl
virtual_wans = {
  "virtual_wan" = {
    create_virtual_wan = false
    name = "virtual_wan"
    resource_group_name = "virtual_wan_rg"
    
    virtual_hubs = {
      "virtual_hub" = {
        name           = "virtual_hub"
        resource_group_name = "virtual_hub_rg"
        create_virtual_hub = false
      }
    }
    connections = {
      "app1-to-hub" = {
        name                       = "app1-to-hub"
        connection_type            = "Vnet"
        virtual_hub_key            = "virtual_hub"
        remote_virtual_network_key = "app1"
      }
   route_tables = {
      "route_table01" = {
        name            = "route_table01"
        virtual_hub_key = "virtual_hub"
        labels          = ["route_table01"]
      }
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
- `virtual_wan` (managed)
- `vpn_gateway` (managed)
- `vpn_gateway_connection` (managed)
- `vpn_site` (managed)
- `virtual_hub` (data)
- `virtual_hub_route_table` (data)
- `virtual_wan` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`name`](#name) | `string` | The name of the Azure Virtual Wan.
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group to use.
[`region`](#region) | `string` | The name of the Azure region to deploy the resources in.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_virtual_wan`](#create_virtual_wan) | `bool` | Controls Virtual Wan creation.
[`disable_vpn_encryption`](#disable_vpn_encryption) | `bool` | Optional boolean flag to specify whether VPN encryption is disabled.
[`allow_branch_to_branch_traffic`](#allow_branch_to_branch_traffic) | `bool` | Optional boolean flag to specify whether branch-to-branch traffic is allowed.
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`remote_virtual_network_ids`](#remote_virtual_network_ids) | `map` | The map of virtual networks ids to connect to hub.
[`virtual_hubs`](#virtual_hubs) | `map` | Map of objects describing virtual hubs to manage.
[`route_tables`](#route_tables) | `map` | Map of objects describing route tables to manage within a Virtual Hub.
[`connections`](#connections) | `map` | Map of objects defining connections within a Virtual Hub.
[`vpn_gateway`](#vpn_gateway) | `object` | Object describing a VPN Gateway to be managed within a Virtual Hub.
[`vpn_sites`](#vpn_sites) | `map` | Map of objects describing VPN sites to be configured within the Azure environment.

### Outputs

Name |  Description
--- | ---
`virtual_wan_ids` | A map of identifiers for the created or sourced Virtual Wans.
`virtual_hub_ids` | A map of identifiers for the created or sourced Virtual Hubs.

### Required Inputs details

#### name

The name of the Azure Virtual Wan.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### resource_group_name

The name of the Resource Group to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### region

The name of the Azure region to deploy the resources in.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### create_virtual_wan

Controls Virtual Wan creation. When set to `true`, creates the Virtual Wan, otherwise just use a pre-existing Virtual Wan.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### disable_vpn_encryption

Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false.

Type: bool

Default value: `false`

<sup>[back to list](#modules-optional-inputs)</sup>

#### allow_branch_to_branch_traffic

Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### remote_virtual_network_ids

The map of virtual networks ids to connect to hub

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_hubs

Map of objects describing virtual hubs to manage.
  
Each entry represents a Virtual Hub configuration with attributes that define its properties. 
By default, the Virtual Hubs specified here will be created. If `create_virtual_hub` is set to `false` 
for a hub entry, the module will not create the Virtual Hub; instead, it will reference existing resources.
  
List of available attributes for each virtual hub entry:

- `name`                   - (`string`, required) the name of the Virtual Hub.
- `create_virtual_hub`     - (`bool`, optional, defaults to `true`) determines whether to create the Virtual Hub. 
                             If set to `false`, existing resources will be referenced.
- `address_prefix`         - (`string`, required when `create_virtual_hub = true`) the address prefix for the Virtual Hub.
                             Must be a subnet no smaller than /24 (Azure recommends /23).
- `region`                 - (`string`, optional) the Azure location for the Virtual Hub.
- `resource_group_name`    - (`string`, optional) name of the Resource Group where the Virtual Hub should exist.
- `hub_routing_preference` - (`string`, optional, defaults to `ExpressRoute`) hub routing preference. 
                             Acceptable values are `ExpressRoute`, `ASPath`, and `VpnGateway`.
- `virtual_wan_id`         - (`string`, optional) ID of a Virtual WAN within which the Virtual Hub should be created.
                             If omitted, it will connect to a local default virtual wan.
- `tags`                   - (`map`, optional) key-value pairs to assign as tags to the Virtual Hub.


Type: 

```hcl
map(object({
    name                   = string
    create_virtual_hub     = optional(bool, true)
    resource_group_name    = optional(string)
    address_prefix         = optional(string)
    region                 = optional(string)
    hub_routing_preference = optional(string, "ExpressRoute")
    virtual_wan_id         = optional(string)
    tags                   = optional(map(string))
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### route_tables

Map of objects describing route tables to manage within a Virtual Hub.

Each entry defines a Virtual Hub Route Table configuration with attributes to control its creation and association.
If `create_route_table` is set to `true`, the module will create a new route table. If set to `false`, 
the module will source an existing route table from the specified Virtual Hub.

List of available attributes for each route table entry:

- `name`                - (`string`, required) Name of the Virtual Hub Route Table.
- `create_route_table`  - (`bool`, required) Indicates whether to create a new route table. 
                          If `false`, the module will reference an existing route table.
- `virtual_hub_key`     - (`string`, optional, required if `create_route_table = true`) ID of the Virtual Hub in which to create 
                          the route table.
- `labels`              - (`set`, optional, required if `create_route_table = true`) Set of labels associated with the route 
                          table.
- `virtual_hub_name`    - (`string`, optional, required if `create_route_table = false`) Name of the existing Virtual Hub Route 
                          Table.
- `resource_group_name` - (`string`, optional, required if `create_route_table = false`) Name of the Resource Group where the 
                          existing Virtual Hub Route Table is located.


Type: 

```hcl
map(object({
    name                = string
    create_route_table  = optional(bool, true)
    virtual_hub_key     = optional(string)
    labels              = optional(set(string))
    virtual_hub_name    = optional(string)
    resource_group_name = optional(string)
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### connections

Map of objects defining connections within a Virtual Hub.
This configuration supports connections to remote virtual networks, Site-to-Site VPNs, and detailed routing options. 
Each entry represents a connection, specifying its type, associated virtual hub, remote network, and VPN details where applicable.

List of available attributes for each connection entry:

- `name`                       - (`string`, required) name of the Connection, unique within the Virtual Hub. 
- `connection_type`            - (`string`, required) type of connection; set to "Vnet" for Virtual Network connections.
- `virtual_hub_key`            - (`string`, required) ID of the Virtual Hub for this connection. 
- `remote_virtual_network_key` - (`string`, required) ID of the Virtual Network to connect to. 
- `vpn_site_key`               - (`string`, optional) ID of the VPN Site associated with this connection.
- `vpn_link`                   - (`list`, optional) a list of VPN link configurations for Site-to-Site VPN connections, 
                                 each with several attributes (see below).
- `routing`                    - (`map`, optional) routing configuration block (see below for available attributes).

**VPN Link Configuration Block**:
The `vpn_link` block is required for Site-to-Site connections and supports the following attributes:

- `vpn_link_name`                  - (`string`, required) name of the VPN link, must be unique within each Site-to-Site 
                                     connection's VPN link list.
- `vpn_site_link_key`              - (`string`, required) the key for the VPN site link.
- `bandwidth_mbps`                 - (`number`, optional) bandwidth limit in Mbps; defaults to `10`.
- `bgp_enabled`                    - (`bool`, optional) enables BGP; defaults to `false`.
- `connection_mode`                - (`string`, optional) connection mode; valid values are `"Default"`, `"InitiatorOnly"`, 
                                      `"ResponderOnly"`. Defaults to `"Default"`.
- `protocol`                       - (`string`, optional) protocol used; valid values are `"IKEv2"`, `"IKEv1"`. 
                                     Defaults to `"IKEv2"`.
- `ratelimit_enabled`              - (`bool`, optional) enables rate limiting; defaults to `false`.
- `route_weight`                   - (`number`, optional) weight for routing; defaults to `0`.
- `shared_key`                     - (`string`, optional) shared key for the connection.
- `local_azure_ip_address_enabled` - (`bool`, optional) enables local Azure IP address; defaults to `false`.
- `ipsec_policy`                   - (`object`, optional) IPsec policy settings with required attributes:
            - `dh_group`                 - (`string`) Diffie-Hellman group, must be one of `"DHGroup14"`, `"DHGroup24"`, `"ECP256"` 
                                            or `"ECP384"`.
            - `ike_encryption_algorithm` - (`string`) IKE encryption algorithm, must be one of `"AES128"`, `"AES256"`, `"GCMAES128"`, 
                                            `"GCMAES256"`.
            - `ike_integrity_algorithm`  - (`string`) IKE integrity algorithm, must be `"SHA256"` or `"SHA384"`.
            - `encryption_algorithm`     - (`string`) encryption algorithm, valid values are `"AES192"`, `"AES128"`, `"AES256"`, `"DES"`, 
                                            `"DES3"`, `"GCMAES192"`, `"GCMAES128"`, `"GCMAES256"`, `"None"`.
            - `integrity_algorithm`      - (`string`) integrity algorithm, must be one of `"SHA256"`, `"GCMAES128"`, or `"GCMAES256"`.
            - `pfs_group`                - (`string`) perfect Forward Secrecy group, must be one of `"ECP384"`, `"ECP256"`, `"PFSMM"`, 
                                            `"PFS1"`, `"PFS14"`, `"PFS2"`, `"PFS24"`, `"PFS2048"`, or `"None"`.
            - `sa_data_size_kb`          - (`number`) security Association data size, must be `0` or within the range `1024 - 2147483647`.
            - `sa_lifetime_sec`          - (`number`) security Association lifetime in seconds.

**Routing Configuration Block**:
The `routing` block configures routing for the connection and supports the following attributes:

- `associated_route_table_key`                - (`string`, optional) associates the connection with a route table.
- `propagated_route_table_keys`               - (`list`, optional) propagates the connection to specified route tables.
- `propagated_route_table_labels`             - (`set`, optional) labels of propagated route tables.
- `static_vnet_route_name`                    - (`string`, optional) name for this static route.
- `static_vnet_route_address_prefixes`        - (`set`, optional) list of CIDR prefixes for the route.
- `static_vnet_route_next_hop_ip_address`     - (`string`, optional) IP address for the next hop in the route.
- `static_vnet_local_route_override_criteria` - (`string`, optional) criteria for overriding local routes; values can be 
                                                 `Contains` or `Equal`. Defaults to `Contains`.


Type: 

```hcl
map(object({
    name                       = string
    connection_type            = string
    virtual_hub_key            = optional(string)
    remote_virtual_network_key = optional(string)
    vpn_site_key               = optional(string)
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

#### vpn_gateway

Object describing a VPN Gateway to be managed within a Virtual Hub.

List of available attributes:

- `name`                - (`string`, required) name of the VPN Gateway.
- `region`              - (`string`, optional) the Azure location where the VPN Gateway should be deployed.
- `resource_group_name` - (`string`, optional) name of the Resource Group where the VPN Gateway should be created.
- `virtual_hub_key`     - (`string`, required) the ID of the Virtual Hub to which the VPN Gateway is associated. 
- `scale_unit`          - (`number`, optional) specifies the scale unit for the VPN Gateway, impacting its performance and 
                          throughput. Defaults to `1`.
- `routing_preference`  - (`string`, optional) specifies the routing preference. Valid values are `"Microsoft Network"`
                          and `"Internet"`.
- `tags`                - (`map`, optional) key-value pairs for tagging the VPN Gateway for identification and organizational 
                          purposes.



Type: 

```hcl
object({
    name                = string
    region              = optional(string)
    resource_group_name = optional(string)
    virtual_hub_key     = string
    scale_unit          = optional(number, 1)
    routing_preference  = optional(string, "Microsoft Network")
    tags                = optional(map(string))
  })
```


Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vpn_sites

Map of objects describing VPN sites to be configured within the Azure environment.

Each entry represents a VPN site with its specific configuration settings, allowing users to define essential details 
about the site such as its name, region, resource group, address prefixes, and associated links.

List of available attributes for each VPN site entry:

- `name`                - (`string`, required) the unique name of the VPN site.
- `region`              - (`string`, optional) the Azure region where the VPN site is located.
- `resource_group_name` - (`string`, optional) the name of the resource group containing the VPN site.
- `address_cidrs`       - (`set`, required) a set of valid IPv4 CIDR blocks associated with the VPN site.
  
**Link Configuration Block**:
The `link` block represents individual connections for the VPN site and supports the following attributes:

- `name`          - (`string`, required) the name of the link.
- `ip_address`    - (`string`, optional) the public IP address of the link, if applicable.
- `fqdn`          - (`string`, optional) fully Qualified Domain Name for the link.
- `provider_name` - (`string`, optional) the name of the service provider associated with the link.
- `speed_in_mbps` - (`number`, optional) the speed of the link in Mbps; defaults to `0`.


Type: 

```hcl
map(object({
    name                = string
    region              = optional(string)
    resource_group_name = optional(string)
    address_cidrs       = set(string)
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
