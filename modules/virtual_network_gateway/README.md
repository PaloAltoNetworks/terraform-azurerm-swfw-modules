<!-- BEGIN_TF_DOCS -->
# Palo Alto Networks Virtual Network Gateway Module for Azure

A terraform module for deploying a VNG (Virtual Network Gateway) and its components required for the VM-Series firewalls in Azure.

## Usage

In order to use module `virtual_network_gateway`, you need to deploy `azurerm_resource_group` and use module `vnet` as prerequisites.
Then you can use below code as an example of calling module to create VNG:

```hcl
module "vng" {
  source = "../../modules/virtual_network_gateway"

  for_each = var.virtual_network_gateways

  location            = var.location
  resource_group_name = local.resource_group.name
  name                = each.value.name
  zones               = each.value.avzones

  type     = each.value.type
  vpn_type = each.value.vpn_type
  sku      = each.value.sku

  active_active                    = each.value.active_active
  default_local_network_gateway_id = each.value.default_local_network_gateway_id
  edge_zone                        = each.value.edge_zone
  enable_bgp                       = each.value.enable_bgp
  generation                       = each.value.generation
  private_ip_address_enabled       = each.value.private_ip_address_enabled

  ip_configuration = [
    for ip_configuration in each.value.ip_configuration :
    merge(ip_configuration, { subnet_id = module.vnet[ip_configuration.vnet_key].subnet_ids[ip_configuration.subnet_name] })
  ]

  vpn_client_configuration  = each.value.vpn_client_configuration
  azure_bgp_peers_addresses = each.value.azure_bgp_peers_addresses
  local_bgp_settings        = each.value.local_bgp_settings
  custom_route              = each.value.custom_route
  ipsec_shared_key          = each.value.ipsec_shared_key
  local_network_gateways    = each.value.local_network_gateways
  connection_mode           = each.value.connection_mode
  ipsec_policy              = each.value.ipsec_policy

  tags = var.tags
}
```

Below there are provided sample values for `virtual_network_gateways` map:

```hcl
virtual_network_gateways = {
  "vng" = {
    name          = "vng"
    type          = "Vpn"
    sku           = "VpnGw2"
    generation    = "Generation2"
    active_active = true
    enable_bgp    = true
    ip_configuration = [
      {
        name             = "001"
        create_public_ip = true
        public_ip_name   = "pip1"
        vnet_key         = "transit"
        subnet_name      = "GatewaySubnet"
      },
      {
        name             = "002"
        create_public_ip = true
        public_ip_name   = "pip2"
        vnet_key         = "transit"
        subnet_name      = "GatewaySubnet"
      }
    ]
    ipsec_shared_key = "test123"
    azure_bgp_peers_addresses = {
      primary_1   = "169.254.21.2"
      secondary_1 = "169.254.22.2"
    }
    local_bgp_settings = {
      asn = "65002"
      peering_addresses = {
        "001" = {
          apipa_addresses = ["primary_1"]
        },
        "002" = {
          apipa_addresses = ["secondary_1"]
        }
      }
    }
    local_network_gateways = {
      "lg1" = {
        local_ng_name   = "lg1"
        connection_name = "cn1"
        gateway_address = "8.8.8.8"
        remote_bgp_settings = [{
          asn                 = "65000"
          bgp_peering_address = "169.254.21.1"
        }]
        custom_bgp_addresses = [
          {
            primary   = "primary_1"
            secondary = "secondary_1"
          }
        ]
      },
      "lg2" = {
        local_ng_name   = "lg2"
        connection_name = "cn2"
        gateway_address = "4.4.4.4"
        remote_bgp_settings = [{
          asn                 = "65000"
          bgp_peering_address = "169.254.22.1"
        }]
        custom_bgp_addresses = [
          {
            primary   = "primary_1"
            secondary = "secondary_1"
          }
        ]
      }
    }
    connection_mode = "InitiatorOnly"
    ipsec_policy = [
      {
        dh_group         = "ECP384"
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "ECP384"
        sa_datasize      = "102400000"
        sa_lifetime      = "14400"
      }
    ]
  }
}
```

## Module's Required Inputs

Name | Type | Description
--- | --- | ---
[`name`](#name) | `string` | The name of the Virtual Network Gateway.
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group to use.
[`location`](#location) | `string` | The name of the Azure region to deploy the resources in.
[`virtual_network_gateway`](#virtual_network_gateway) | `object` | A map containing the basic Virtual Network Gateway configuration.
[`network`](#network) | `object` | Network configuration of the Virtual Network Gateway.
[`azure_bgp_peer_addresses`](#azure_bgp_peer_addresses) | `map` | Map of IP addresses used on Azure side for BGP.
[`bgp`](#bgp) | `object` | A map controlling the BGP configuration used by this Virtual Network Gateway.
[`local_network_gateways`](#local_network_gateways) | `map` | Map of local network gateways and their connections.


## Module's Optional Inputs

Name | Type | Description
--- | --- | ---
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`vpn_clients`](#vpn_clients) | `map` | VPN client configurations (IPSec point-to-site connections).



## Module's Outputs

Name |  Description
--- | ---
`public_ip` | Public IP addresses for Virtual Network Gateway
`ipsec_policy` | IPsec policy used for Virtual Network Gateway connection

## Module's Nameplate


Requirements needed by this module:

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 3.80


Providers used in this module:

- `azurerm`, version: ~> 3.80




Resources used in this module:

- `local_network_gateway` (managed)
- `public_ip` (managed)
- `virtual_network_gateway` (managed)
- `virtual_network_gateway_connection` (managed)
- `public_ip` (data)

## Inputs/Outpus details

### Required Inputs


#### name

The name of the Virtual Network Gateway.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### resource_group_name

The name of the Resource Group to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### location

The name of the Azure region to deploy the resources in.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>


#### virtual_network_gateway

A map containing the basic Virtual Network Gateway configuration.

You configure the size, capacity and capabilities with 4 parameters that heavily depend on each other. Please follow the table
below for details on available combinations:

# REFACTOR : add here a table with possible config combinations

Following properties are available:

- `type`          - (`string`, optional, defaults to `Vpn`) the type of the Virtual Network Gateway, possible values are: `Vpn`
                    or `ExpressRoute`.
- `vpn_type`      - (`string`, optional, defaults to `RouteBased`) the routing type of the Virtual Network Gateway, possible
                    values are: `RouteBased` or `PolicyBased`.
- `generation`    - (`string`, optional, defaults to `Generation1`) the Generation of the Virtual Network gateway, possible
                    values are: `None`, `Generation1` or `Generation2`.
- `sku`           - (`string`, optional, defaults to `Basic`) sets the size and capacity of the virtual network gateway.
- `active_active` - (`bool`, optional, defaults to `false`) when set to true creates an active-active Virtual Network Gateway,
                    active-passive otherwise. Not supported for `Basic` and `Standard` SKUs.
- `custom_routes` - (`map`, optional, defaults to `{}`) a map defining custom routes. Each route is a list of address blocks
                    reserved for this Virtual Network (in CIDR notation). Keys in this map are only to identify the CIDR blocks,
                    values are lists of the actual address blocks



Type: 

```hcl
object({
    type          = optional(string, "Vpn")
    vpn_type      = optional(string, "RouteBased")
    sku           = optional(string, "Basic")
    active_active = optional(bool, false)
    generation    = optional(string, "Generation1")
    custom_routes = optional(map(list(string)), {})
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

#### network

Network configuration of the Virtual Network Gateway.

Following properties are available:

- `subnet_id`                        - (`string`, required) ID of a Subnet in which the Virtual Network Gateway will be created.
                                       This has to be a dedicated Subnet names `GatewaySubnet`.
- `public_ip_zones`                  - (`list`, optional, defaults to `["1", "2", "3"]`) a list of Availability Zones in which
                                       the Virtual Network Gateway will be available.
- `ip_configurations`                - (`map`, required) a map defining the Public IPs used by the Virtual Network Gateway.
                                       Contains 2 properties:
  - `primary`   - (`map`, required) a map defining the primary Public IP address, following properties are available:
    - `name`                          - (`string`, required) name of the IP config.
    - `create_public_ip`              - (`bool`, optional, defaults to `true`) controls if a Public IP is created or sourced.
    - `public_ip_name`                - (`string`, required) name of a Public IP resource, depending on the value of 
                                        `create_public_ip` property this will be a name of a newly create or existing resource
                                        (for values of `true` and `false` accordingly).
    - `dynamic_private_ip_allocation` - (`bool`, optional, defaults to `true`) controls if the private IP address is assigned
                                        dynamically or statically.
  - `secondary` - (`map`, optional, defaults to `null`) a map defining the secondary Public IP resource. Required only for
                  `type` set to `Vpn` and `active-active` set to `true`. Same properties available like in `primary` property.
- `private_ip_address_enabled`       - (`bool`, optional, defaults to `false`) controls whether the private IP is enabled on the
                                       gateway.
- `default_local_network_gateway_id` - (`string`, optional, defaults to `null`) the ID of the local Network Gateway. When set
                                       the outbound Internet traffic from the virtual network, in which the gateway is created,
                                       will be routed through local network gateway (forced tunnelling).
- `edge_zone`                        - (`string`, optional, defaults to `null`) specifies the Edge Zone within the Azure Region
                                       where this Virtual Network Gateway should exist.



Type: 

```hcl
object({
    subnet_id       = string
    public_ip_zones = optional(list(string), ["1", "2", "3"])
    ip_configurations = object({
      primary = object({
        name                          = string
        create_public_ip              = optional(bool, true)
        public_ip_name                = string
        private_ip_address_allocation = optional(string, "Dynamic")
      })
      secondary = optional(object({ # REFACTOR: add precondition that would make this required when active-active is set to true and type == Vpn
        name                          = string
        create_public_ip              = optional(bool, true)
        public_ip_name                = string
        private_ip_address_allocation = optional(string, "Dynamic")
      }))
    })
    private_ip_address_enabled       = optional(bool, false)
    default_local_network_gateway_id = optional(string)
    edge_zone                        = optional(string)
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

#### azure_bgp_peer_addresses

Map of IP addresses used on Azure side for BGP.

Map is used to not to duplicate IP address and refer to keys while configuring:
- `custom_bgp_addresses`
- `peering_addresses` in `local_bgp_settings`

Example:

```hcl
azure_bgp_peers_addresses = {
  primary_1   = "169.254.21.2"
  secondary_1 = "169.254.22.2"
  primary_2   = "169.254.21.6"
  secondary_2 = "169.254.22.6"
}
```


Type: map(string)

<sup>[back to list](#modules-required-inputs)</sup>

#### bgp

A map controlling the BGP configuration used by this Virtual Network Gateway.

Following properties are available:

- `enable`        - (`bool`, optional, defaults to `false`) controls whether BGP (Border Gateway Protocol) will be enabled for
                    this Virtual Network Gateway
- `configuration` - (`map`, optional, defaults to `null`) contains BGP configuration, required when `enable` is set to `true`.
                    Contains the following properties:
  - `asn`                         - (`string`, required) the Autonomous System Number (ASN) to use as part of the BGP.
  - `peer_weigth`                 - (`number`, optional`, defaults to `null`) weight added to routes which have been learned
                                    through BGP peering. Values are between `0` and `100`.
  - `primary_peering_addresses`   - (`map`, required) a map defining peering addresses, following properties are available:
    - `name`               - (`string`, required) name of the configuration.
    - `apipa_address_keys` - (`list`, required) list of keys identifying addresses defined in `azure_bgp_peer_addresses`.
    - `default_addresses`  - (`list`, optional, defaults to `null`) is the list of peering address assigned to the BGP peer of
                             the Virtual Network Gateway.
  - `secondary_peering_addresses` - (`map`, optional, defaults to `null`) a map defining secondary peering addresses, required
                                    only for `active-active` deployments. Same properties are available.


Type: 

```hcl
object({
    enable = optional(bool, false)
    configuration = optional(object({
      asn         = string
      peer_weight = optional(number)
      primary_peering_addresses = object({
        name               = string
        apipa_address_keys = list(string)
        default_addresses  = optional(list(string))
      })
      secondary_peering_addresses = optional(object({ # REFACTOR : add a precondition like for network configuration
        name               = string
        apipa_address_keys = list(string)
        default_addresses  = optional(list(string))
      }))
    }))
  })
```


<sup>[back to list](#modules-required-inputs)</sup>


#### local_network_gateways

Map of local network gateways and their connections.

Every object in the map contains following attributes:
  
- `name`                 - (`string`, required) the name of the local network gateway.
- `remote_bgp_settings`  - (`list`, optional, defaults to `[]`) block containing Local Network Gateway's BGP speaker settings:
  - `asn`                 - (`string`, required) the BGP speaker's ASN.
  - `bgp_peering_address` - (`string`, required) the BGP peering address and BGP identifier of this BGP speaker.
  - `peer_weight`         - (`number`, optional, defaults to `null`) the weight added to routes learned from this BGP speaker.
- `gateway_address`      - (`string`, optional, defaults to `null`) the gateway IP address to connect with.
- `address_space`        - (`list`, optional, defaults to `[]`) the list of string CIDRs representing the address spaces
                           the gateway exposes.
- `custom_bgp_addresses` - (`list`, optional, defaults to `[]`) Border Gateway Protocol custom IP Addresses,
                           which can only be used on IPSec / active-active connections. Object contains 2 attributes:
  - `primary_key`   - (`string`, required) single IP address that is part of the azurerm_virtual_network_gateway
                      ip_configuration (first one)
  - `secondary_key` - (`string`, optional, defaults to `null`) single IP address that is part of the
                      azurerm_virtual_network_gateway ip_configuration (second one)
- `connection`           - (`map`, required) a map defining configuration for a VPN connection between Azure VNG and on-premises
                           VPN device. Contains the following properties:
  - `name`            - (`string`, required) the name of the virtual network gateway connection.
  - `ipsec_policies`  - (`list`, required) list of IPsec policies used for Virtual Network Connection. A single policy consist
                        of the following properties:
    - `dh_group`         - (`string`, required) the DH group used in IKE phase 1 for initial SA.
    - `ike_encryption`   - (`string`, required) the IKE encryption algorithm.
    - `ike_integrity`    - (`string`, required) the IKE integrity algorithm.
    - `ipsec_encryption` - (`string`, required) the IPSec encryption algorithm.
    - `ipsec_integrity`  - (`string`, required) the IPSec integrity algorithm.
    - `pfs_group`        - (`string`, required) the DH group used in IKE phase 2 for new child SA.
    - `sa_datasize`      - (`string`, optional, defaults to `102400000`) the IPSec SA payload size in KB. Must be at least
                           1024 KB.
    - `sa_lifetime`      - (`string`, optional, defaults to `27000`) the IPSec SA lifetime in seconds. Must be at least 300
                           seconds.
  - `connection_type` - (`string`, optional, defaults to `IPsec`) a VPN connection type, can be one of: `IPsec`, `ExpressRoute`
                        or `Vnet2Vnet`.
  - `connection_mode` - (`string`, optional, defaults to `Default) connection mode to use, can be one of: `Default`,
                        `InitiatorOnly` or `ResponderOnly`.
  - `shared_key`      - (`string`, optional, defaults to `null`) a shared IPSec key used during connection creation.



Type: 

```hcl
map(object({
    name = string
    remote_bgp_settings = optional(object({
      asn                 = string
      bgp_peering_address = string
      peer_weight         = optional(number)
    }))
    address_space   = optional(list(string), [])
    gateway_address = optional(string)
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
        sa_datasize      = optional(string, "102400000")
        sa_lifetime      = optional(string, "27000")
      }))
      type       = optional(string, "IPsec")
      mode       = optional(string, "Default")
      shared_key = optional(string)
    })
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>



### Optional Inputs





#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>





#### vpn_clients

VPN client configurations (IPSec point-to-site connections).

This is a map, where each value is a VPN client configuration. Keys are just names describing a particular configuration. They
are not being used in the actual deployment.

Following properties are available:

- `address_space`           - (`string`, required) the address space out of which IP addresses for vpn clients will be taken.
                              You can provide more than one address space, e.g. in CIDR notation.
- `aad_tenant`              - (`string`, optional, defaults to `null`) AzureAD Tenant URL
- `aad_audience`            - (`string`, optional, defaults to `null`) the client id of the Azure VPN application.
                              See Create an Active Directory (AD) tenant for P2S OpenVPN protocol connections for values
- `aad_issuer`              - (`string`, optional, defaults to `null`) the STS url for your tenant
- `root_certificates`       - (`map`, optional, defaults to `{}`) a map defining root certificates used to sign client 
                              certificates used by VPN clients. The key is a name of the certificate, value is the public
                              certificate in PEM format.
- `revoked_certificates     - (`map`, optional, defaults to `null`) a map defining revoked certificates. The key is a name of
                              the certificate, value is the thumbprint of the certificate.
- `radius_server_address`   - (`string`, optional, defaults to `null`) the address of the Radius server.
- `radius_server_secret`    - (`string`, optional, defaults to `null`) the secret used by the Radius server.
- `vpn_client_protocols`    - (`list(string)`, optional, defaults to `null`) list of the protocols supported by the vpn client.
                              The supported values are SSTP, IkeV2 and OpenVPN. Values SSTP and IkeV2 are incompatible with
                              the use of aad_tenant, aad_audience and aad_issuer.
- `vpn_auth_types`          - (`list(string)`, optional, defaults to `null`) list of the vpn authentication types for
                              the virtual network gateway. The supported values are AAD, Radius and Certificate.



Type: 

```hcl
map(object({
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
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>



<!-- END_TF_DOCS -->