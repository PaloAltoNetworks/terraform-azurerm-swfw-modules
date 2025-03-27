# Palo Alto Networks vWAN Module for Azure

A Terraform module for deploying a Virtual WAN (vWAN) and its components required for the firewalls in Azure.

## Usage

This module is designed to work in several *modes* depending on which variables or flags are set. Most common usage scenarios are:

- create all - creates a vWAN, vHub, Connections and Route Tables. In this mode, a vWAN and vHub are created. The Connections and Route Tables are assigned to the vHub:

  ```hcl
  name = "virtual_wan"
  virtual_hubs = {
    "vhub" = {
      name           = "virtual_hub"
      address_prefix = "10.0.0.0/24"
    }
  }
  connections = {
    "app1-to-vhub" = {
      name                       = "app1-to-vhub"
      connection_type            = "Vnet"
      virtual_hub_key            = "vhub"
      remote_virtual_network_key = "app1"
    }
  }
  route_tables = {
    "default" = {
      name            = "default-rt"
      virtual_hub_key = "vhub"
      labels          = ["default-rt"]
    }
  }
  ```

- sources a vWAN and vHub but creates Connections and Route Tables:

  ```hcl
  create_virtual_wan  = false
  name                = "virtual_wan"
  resource_group_name = "virtual_wan_rg"
  virtual_hubs = {
    "vhub" = {
      create              = false
      name                = "virtual_hub"
      resource_group_name = "virtual_wan_rg"
    }
  }
  connections = {
    "app1-to-vhub" = {
      name                       = "app1-to-vhub"
      connection_type            = "Vnet"
      virtual_hub_key            = "vhub"
      remote_virtual_network_key = "app1"
    }
  }
  route_tables = {
    "default" = {
      name            = "default-rt"
      virtual_hub_key = "vhub"
      labels          = ["default-rt"]
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
[`name`](#name) | `string` | The name of the Azure Virtual WAN.
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group to use.
[`region`](#region) | `string` | The name of the Azure region to deploy the resources in.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`create_virtual_wan`](#create_virtual_wan) | `bool` | Controls Virtual WAN creation.
[`allow_branch_to_branch_traffic`](#allow_branch_to_branch_traffic) | `bool` | Optional boolean flag to specify whether branch-to-branch traffic is allowed.
[`remote_virtual_network_ids`](#remote_virtual_network_ids) | `map` | The map of Virtual Networks IDs to connect to Virtual Hub.
[`disable_vpn_encryption`](#disable_vpn_encryption) | `bool` | Optional boolean flag to specify whether VPN encryption is disabled.
[`virtual_hubs`](#virtual_hubs) | `map` | Map of objects describing Virtual Hubs (vHubs) to manage.
[`connections`](#connections) | `map` | Map of objects defining connections within a Virtual Hub.
[`route_tables`](#route_tables) | `map` | Map of objects describing route tables to manage within a Virtual Hub.
[`vpn_gateway`](#vpn_gateway) | `object` | Object describing a VPN Gateway to be managed within a Virtual Hub.
[`vpn_sites`](#vpn_sites) | `map` | Map of objects describing VPN sites to be configured within the Azure environment.

### Outputs

Name |  Description
--- | ---
`virtual_wan_ids` | A map of identifiers for the created or sourced Virtual Wans.
`virtual_hub_ids` | A map of identifiers for the created or sourced Virtual Hubs.

### Required Inputs details

#### name

The name of the Azure Virtual WAN.

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

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### create_virtual_wan

Controls Virtual WAN creation. When set to `true`, creates the Virtual WAN, otherwise just uses a pre-existing Virtual WAN.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### allow_branch_to_branch_traffic

Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### remote_virtual_network_ids

The map of Virtual Networks IDs to connect to Virtual Hub.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### disable_vpn_encryption

Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false.

Type: bool

Default value: `false`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_hubs

Map of objects describing Virtual Hubs (vHubs) to manage.
  
Each entry represents a Virtual Hub configuration with attributes that define its properties. 
By default, the Virtual Hubs specified here will be created. If `create` is set to `false` for a hub entry, the module will not
create the Virtual Hub; instead, it will reference existing resources.
  
List of available attributes for each Virtual Hub entry:

- `create`                 - (`bool`, optional, defaults to `true`) determines whether to create the Virtual Hub. If set to
                             `false`, existing resources will be referenced.
- `name`                   - (`string`, required) the name of the Virtual Hub.
- `resource_group_name`    - (`string`, optional) name of the Resource Group where the Virtual Hub should exist.
- `region`                 - (`string`, optional) the Azure location for the Virtual Hub.
- `address_prefix`         - (`string`, required when `create = true`) the address prefix for the Virtual Hub. Must be a subnet
                             no smaller than /24 (Microsoft recommends /23).
- `hub_routing_preference` - (`string`, optional, defaults to `ExpressRoute`) Virtual Hub routing preference. Acceptable values
                             are `ExpressRoute`, `ASPath` and `VpnGateway`.
- `virtual_wan_id`         - (`string`, optional) ID of a Virtual WAN within which the Virtual Hub should be created. If
                             omitted, it will connect to a local default Virtual WAN.


Type: 

```hcl
map(object({
    create                 = optional(bool, true)
    name                   = string
    resource_group_name    = optional(string)
    region                 = optional(string)
    address_prefix         = optional(string)
    hub_routing_preference = optional(string, "ExpressRoute")
    virtual_wan_id         = optional(string)
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
- `connection_mode`                - (`string`, optional) connection mode; valid values are `Default`, `InitiatorOnly`, 
                                      `ResponderOnly`. Defaults to `Default`.
- `protocol`                       - (`string`, optional) protocol used; valid values are `IKEv2`, `IKEv1`. Defaults to `IKEv2`.
- `ratelimit_enabled`              - (`bool`, optional) enables rate limiting; defaults to `false`.
- `route_weight`                   - (`number`, optional) weight for routing; defaults to `0`.
- `shared_key`                     - (`string`, optional) shared key for the connection.
- `local_azure_ip_address_enabled` - (`bool`, optional) enables local Azure IP address; defaults to `false`.
- `ipsec_policy`                   - (`object`, optional) IPSec policy settings with required attributes:

  - `dh_group`                 - (`string`) Diffie-Hellman group, must be one of `DHGroup14`, `DHGroup24`, `ECP256` or `ECP384`.
  - `ike_encryption_algorithm` - (`string`) IKE encryption algorithm, must be one of `AES128`, `AES256`, `GCMAES128`, 
                                 `GCMAES256`.
  - `ike_integrity_algorithm`  - (`string`) IKE integrity algorithm, must be `SHA256` or `SHA384`.
  - `encryption_algorithm`     - (`string`) encryption algorithm, valid values are `AES192`, `AES128`, `AES256`, `DES`, `DES3`,
                                 `GCMAES192`, `GCMAES128`, `GCMAES256`, `None`.
  - `integrity_algorithm`      - (`string`) integrity algorithm, must be one of `SHA256`, `GCMAES128`, or `GCMAES256`.
  - `pfs_group`                - (`string`) Perfect Forward Secrecy group, must be one of `ECP384`, `ECP256`, `PFSMM`, `PFS1`,
                                 `PFS14`, `PFS2`, `PFS24`, `PFS2048`, or `None`.
  - `sa_data_size_kb`          - (`number`) Security Association data size, must be `0` or within the range `1024 - 2147483647`.
  - `sa_lifetime_sec`          - (`number`) Security Association lifetime in seconds.

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

#### route_tables

Map of objects describing route tables to manage within a Virtual Hub.

Each entry defines a Virtual Hub Route Table configuration with attributes to control its creation and association.
If `create` is set to `true`, the module will create a new route table. If set to `false`, the module will source an existing
route table from the specified Virtual Hub.

List of available attributes for each route table entry:

- `create`              - (`bool`, optional, defaults to `true`) indicates whether to create a new Route Table. If `false`, the
                          module will reference an existing Route Table.
- `name`                - (`string`, required) name of the Virtual Hub Route Table.
- `resource_group_name` - (`string`, optional, required if `create = false`) name of the Resource Group where the existing
                          Virtual Hub Route Table is located.
- `virtual_hub_key`     - (`string`, optional, required if `create = true`) ID of the Virtual Hub in which to create the Route
                          Table.
- `labels`              - (`set`, optional, required if `create = true`) Set of labels associated with the Route Table.
- `virtual_hub_name`    - (`string`, optional, required if `create = false`) name of the existing Virtual Hub Route Table.


Type: 

```hcl
map(object({
    create              = optional(bool, true)
    name                = string
    resource_group_name = optional(string)
    virtual_hub_key     = optional(string)
    labels              = optional(set(string))
    virtual_hub_name    = optional(string)
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
- `routing_preference`  - (`string`, optional) specifies the routing preference. Valid values are `Microsoft Network` and
                          `Internet`.


Type: 

```hcl
object({
    name                = string
    resource_group_name = optional(string)
    region              = optional(string)
    virtual_hub_key     = string
    scale_unit          = optional(number, 1)
    routing_preference  = optional(string, "Microsoft Network")
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
- `resource_group_name` - (`string`, optional) the name of the resource group containing the VPN site.
- `region`              - (`string`, optional) the Azure region where the VPN site is located.
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
    resource_group_name = optional(string)
    region              = optional(string)
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
