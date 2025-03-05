variable "name" {
  description = "The name of the Virtual Network Gateway."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group to use."
  type        = string
}

variable "region" {
  description = "The name of the Azure region to deploy the resources in."
  type        = string
}

variable "tags" {
  description = "The map of tags to assign to all created resources."
  default     = {}
  type        = map(string)
}

variable "subnet_id" {
  description = <<-EOF
  An ID of a Subnet in which the Virtual Network Gateway will be created.

  This has to be a dedicated Subnet named `GatewaySubnet`.
  EOF
  type        = string
}

variable "zones" {
  description = <<-EOF
  After provider version 3.x you need to specify in which availability zone(s) you want to place a Public IP address.

  For zone-redundant with 3 availability zones in current region, value will be:
  ```["1","2","3"]```
  EOF
  default     = null
  type        = list(string)
  validation {
    condition = var.zones == null || (var.zones != null ? (
      length(var.zones) == 3 && length(setsubtract(var.zones, ["1", "2", "3"])) == 0
    ) : true)
    error_message = "No zones (for non-AZ SKU) or all 3 zones (for AZ SKU) are expected."
  }
}

variable "edge_zone" {
  description = "Specifies the Edge Zone within the Azure Region where this Virtual Network Gateway should exist."
  default     = null
  type        = string
}

variable "instance_settings" {
  description = <<-EOF
  A map containing the basic Virtual Network Gateway instance settings.

  You configure the size, capacity and capabilities with 3/4 parameters that heavily depend on each other. Please follow the
  table below for details on available combinations:

  <table>
    <tr>
      <th>type</th>
      <th>generation</th>
      <th>sku</th>
    </tr>
    <tr>
      <td rowspan="6">ExpressRoute</td>
      <td rowspan="6">N/A</td>
      <td>Standard</td>
    </tr>
    <tr><td>HighPerformance</td></tr>
    <tr><td>UltraPerformance</td></tr>
    <tr><td>ErGw1AZ</td></tr>
    <tr><td>ErGw2AZ</td></tr>
    <tr><td>ErGw3AZ</td></tr>
    <tr>
      <td rowspan="11">Vpn</td>
      <td rowspan="3">Generation1</td>
      <td>Basic</td>
    </tr>
    <tr><td>VpnGw1</td></tr>
    <tr><td>VpnGw1AZ</td></tr>
    <tr>
      <td rowspan="8">Generation1/Generation2</td>
      <td>VpnGw2</td>
    </tr>
    <tr><td>VpnGw3</td></tr>
    <tr><td>VpnGw4</td></tr>
    <tr><td>VpnGw5</td></tr>
    <tr><td>VpnGw2AZ</td></tr>
    <tr><td>VpnGw3AZ</td></tr>
    <tr><td>VpnGw4AZ</td></tr>
    <tr><td>VpnGw5AZ</td></tr>
  </table>

  Following properties are available:

  - `type`          - (`string`, optional, defaults to `Vpn`) the type of the Virtual Network Gateway, possible values are: `Vpn`
                      or `ExpressRoute`.
  - `vpn_type`      - (`string`, optional, defaults to `RouteBased`) the routing type of the Virtual Network Gateway, possible
                      values are: `RouteBased` or `PolicyBased`.
  - `generation`    - (`string`, optional, defaults to `Generation1`) the Generation of the Virtual Network Gateway, possible
                      values are: `None`, `Generation1` or `Generation2`. This property is ignored when type is set to 
                      `ExpressRoute`.
  - `sku`           - (`string`, optional, defaults to `Basic`) sets the size and capacity of the Virtual Network Gateway.
  - `active_active` - (`bool`, optional, defaults to `false`) when set to true creates an active-active Virtual Network Gateway,
                      active-passive otherwise. Not supported for `Basic` and `Standard` SKUs.
  EOF
  type = object({
    type          = optional(string, "Vpn")
    vpn_type      = optional(string, "RouteBased")
    generation    = optional(string, "Generation1")
    sku           = optional(string, "Basic")
    active_active = optional(bool, false)

  })
  validation { # type
    condition     = contains(["Vpn", "ExpressRoute"], var.instance_settings.type)
    error_message = <<-EOF
    The `virtual_network_gateway.type` property can take one of the following values: "Vpn" or "ExpressRoute".
    EOF
  }
  validation { # vpn_type
    condition     = contains(["RouteBased", "PolicyBased"], var.instance_settings.vpn_type)
    error_message = <<-EOF
    The `virtual_network_gateway.vpn_type` property can take one of the following values: "RouteBased" or "PolicyBased".
    EOF
  }
  validation { # generation
    condition     = contains(["Generation1", "Generation2", "None"], var.instance_settings.generation)
    error_message = <<-EOF
    The `virtual_network_gateway.generation` property can take one of the following values: "Generation1" or "Generation2"
    or "None".
    EOF
  }
  validation { # type, generation & sku
    condition = var.instance_settings.generation == "Generation2" && var.instance_settings.type == "Vpn" ? contains(
      ["VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.instance_settings.sku
    ) : true
    error_message = <<-EOF
    For `sku` of "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ" or "VpnGw5AZ" the `generation`
    property has to be set to `Generation2` and `type` to `Vpn`.
    EOF
  }
  validation { # type & sku
    condition = (var.instance_settings.type == "Vpn" && contains(
      ["Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"],
      var.instance_settings.sku
      )) || (
      var.instance_settings.type == "ExpressRoute" && contains(
        ["Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ"], var.instance_settings.sku
      )
    )
    error_message = <<-EOF
    Invalid combination of `sku` and `type`. Please check documentation for `var.virtual_network_gateway`.
    EOF
  }
  validation { # active_active
    condition     = var.instance_settings.type == "ExpressRoute" ? !var.instance_settings.active_active : true
    error_message = <<-EOF
    The `active_active` property has to be set to `false` (default) when type is `ExpressRoute`.
    EOF
  }
}

variable "ip_configurations" {
  description = <<-EOF
  A map defining the Public IPs used by the Virtual Network Gateway.
  
  Following properties are available:
  - `primary`   - (`map`, required) a map defining the primary Public IP address, following properties are available:
    - `name`                           - (`string`, required) name of the IP config.
    - `create_public_ip`               - (`bool`, optional, defaults to `true`) controls if a Public IP is created or sourced.
    - `public_ip_name`                 - (`string`, optional) name of a Public IP resource, required unless `public_ip` module
                                         and `public_ip_id` property are used. Depending on the value of `create_public_ip`
                                         property, this will be a name of a newly created or existing resource (for values of
                                         `true` and `false` accordingly).
    - `public_ip_resource_group_name`  - (`string`, optional, defaults to the Load Balancer's RG) name of a Resource Group
                                         hosting an existing Public IP resource.
    - `public_ip_id`                   - (`string`, optional, defaults to `null`) ID of the public IP to associate with the
                                         interface. Property is used when public IP is not created or sourced within this module.
    - `dynamic_private_ip_allocation`  - (`bool`, optional, defaults to `true`) controls if the private IP address is assigned
                                         dynamically or statically.
  - `secondary` - (`map`, optional, defaults to `null`) a map defining the secondary Public IP address resource. Required only
                  for `type` set to `Vpn` and `active-active` set to `true`. Same properties available as for `primary` property.

  EOF
  type = object({
    primary = object({
      name                          = string
      create_public_ip              = optional(bool, true)
      public_ip_name                = optional(string)
      public_ip_resource_group_name = optional(string)
      public_ip_id                  = optional(string)
      private_ip_address_allocation = optional(string, "Dynamic")
    })
    secondary = optional(object({
      name                          = string
      create_public_ip              = optional(bool, true)
      public_ip_name                = optional(string)
      public_ip_id                  = optional(string)
      private_ip_address_allocation = optional(string, "Dynamic")
    }))
  })
  validation { # name
    condition = var.ip_configurations.secondary != null ? (
      var.ip_configurations.primary.name != var.ip_configurations.secondary.name
    ) : true
    error_message = <<-EOF
    The `name` property has to be unique among all IP configurations.
    EOF
  }
  validation { # public_ip_id, public_ip_name
    condition = alltrue([
      (var.ip_configurations.primary.public_ip_name != null || var.ip_configurations.primary.public_ip_id != null),
      (
        var.ip_configurations.secondary != null ? (
          var.ip_configurations.secondary.public_ip_name != null || var.ip_configurations.secondary.public_ip_id != null
        ) : true
      )
    ])
    error_message = <<-EOF
    Either `public_ip_name` or `public_ip_id` property must be set.
    EOF
  }
  validation { # public_ip_id, create_public_ip, public_ip_name
    condition = alltrue([
      (
        var.ip_configurations.primary.public_ip_id != null ?
        var.ip_configurations.primary.create_public_ip == false &&
        var.ip_configurations.primary.public_ip_name == null : true
      ),
      (
        var.ip_configurations.secondary != null ? (
          var.ip_configurations.secondary.public_ip_id != null ?
          var.ip_configurations.secondary.create_public_ip == false &&
          var.ip_configurations.secondary.public_ip_name == null : true
        ) : true
      )
    ])
    error_message = <<-EOF
    When using `public_ip_id` property, `create_public_ip` must be set to `false` and `public_ip_name` must not be set.
    EOF
  }
  validation { # private_ip_address_allocation
    condition = contains(["Dynamic", "Static"], var.ip_configurations.primary.private_ip_address_allocation) && (
      var.ip_configurations.secondary != null ? (
        contains(["Dynamic", "Static"], var.ip_configurations.secondary.private_ip_address_allocation)
      ) : true
    )
    error_message = <<EOF
    Possible values for `private_ip_address_allocation` are "Dynamic" or "Static".
    EOF
  }
}

variable "private_ip_address_enabled" {
  description = "Controls whether the private IP is enabled on the Virtual Netowkr Gateway."
  default     = false
  type        = bool
}

variable "default_local_network_gateway_id" {
  description = <<-EOF
  The ID of the Local Network Gateway.

  When set, the outbound Internet traffic from the Virtual Network, in which the gateway is created, will be routed through Local
  Network Gateway (forced tunnelling).
  EOF
  default     = null
  type        = string
}

variable "azure_bgp_peer_addresses" {
  description = <<-EOF
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
  EOF
  default     = {}
  nullable    = false
  type        = map(string)
  validation {
    condition = alltrue([
      for _, v in var.azure_bgp_peer_addresses :
      cidrhost("${v}/24", 0) == cidrhost("169.254.21.0/24", 0) || cidrhost("${v}/24", 0) == cidrhost("169.254.22.0/24", 0)
    ])
    error_message = <<-EOF
    The value of a peer BGP address should be contained within the following address spaces: 169.254.21.0/24 or 169.254.22.0/24.
    EOF
  }
}

variable "bgp" {
  description = <<-EOF
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
  EOF
  default     = null
  type = object({
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
  })
  validation { # configuration
    condition = var.bgp == null ? true : (var.bgp.enable && var.bgp.configuration != null) || (
      !var.bgp.enable && var.bgp.configuration == null
    )
    error_message = <<-EOF
    The `configuration` property is required only when `enabled` is set to `true`.
    EOF
  }
  validation { # configuration.peer_weight
    condition = var.bgp == null ? true : (
      var.bgp.configuration.peer_weight == null ? true : (
        var.bgp.configuration.peer_weight >= 0 && var.bgp.configuration.peer_weight <= 100
      )
    )
    error_message = <<-EOF
    Possible values for `peer_weight` are between 0 and 100.
    EOF
  }
}

variable "local_network_gateways" {
  description = <<-EOF
  Map of Local Network Gateways and their connections.

  Every object in the map contains following attributes:
  
  - `name`                 - (`string`, required) the name of the Local Network Gateway.
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
    - `name`            - (`string`, required) the name of the Virtual Network Gateway connection.
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
    - `connection_mode` - (`string`, optional, defaults to `Default`) connection mode to use, can be one of: `Default`,
                          `InitiatorOnly` or `ResponderOnly`.
    - `shared_key`      - (`string`, optional, defaults to `null`) a shared IPSec key used during connection creation.
  EOF
  default     = {}
  nullable    = false
  type = map(object({
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
  validation { # remote_bgp_settings & address_space
    condition = alltrue([
      for _, v in var.local_network_gateways :
      length(coalesce(v.remote_bgp_settings, {})) > 0 || length(v.address_space) > 0
    ])
    error_message = <<-EOF
    You have to define at least one: `remote_bpg_settings` or `address_space`.
    EOF
  }
  validation { # connection.type
    condition = alltrue([
      for _, v in var.local_network_gateways : contains(["IPsec", "ExpressRoute", "Vnet2Vnet"], v.connection.type)
    ])
    error_message = <<-EOF
    The `connection_type` can be one of either: "IPsec", "ExpressRoute" or "Vnet2Vnet".
    EOF
  }
  validation { # connection.mode
    condition = alltrue([
      for _, v in var.local_network_gateways : contains(["Default", "InitiatorOnly", "ResponderOnly"], v.connection.mode)
    ])
    error_message = <<-EOF
    The `connection_mode` property can be one of either: "Default", "InitiatorOnly" or "ResponderOnly".
    EOF
  }
  validation { # connection.ipsec_policies.dh_group
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(
          ["DHGroup1", "DHGroup14", "DHGroup2", "DHGroup2048", "DHGroup24", "ECP256", "ECP384", "None"],
          ipsec_policy.dh_group
        )
      ]
    ]))
    error_message = <<-EOF
    Possible values for `dh_group` are "DHGroup1", "DHGroup14", "DHGroup2", "DHGroup2048", "DHGroup24", "ECP256", "ECP384" or
    "None".
    EOF
  }
  validation { # connection.ipsec_policies.ike_encryption
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(["AES128", "AES192", "AES256", "DES", "DES3", "GCMAES128", "GCMAES256"], ipsec_policy.ike_encryption)
    ]]))
    error_message = <<-EOF
    Possible values for `ike_encryption` are "AES128", "AES192", "AES256", "DES", "DES3", "GCMAES128" or "GCMAES256".
    EOF
  }
  validation { # connection.ipsec_policies.ike_integrity
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(["GCMAES128", "GCMAES256", "MD5", "SHA1", "SHA256", "SHA384"], ipsec_policy.ike_integrity)
    ]]))
    error_message = <<-EOF
    Possible values for `ike_integrity` are "GCMAES128", "GCMAES256", "MD5", "SHA1", "SHA256", or "SHA384".
    EOF
  }
  validation { # connection.ipsec_policies.ipsec_encryption
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(
          ["AES128", "AES192", "AES256", "DES", "DES3", "GCMAES128", "GCMAES192", "GCMAES256", "None"],
          ipsec_policy.ipsec_encryption
        )
      ]
    ]))
    error_message = <<-EOF
    Possible values for `ipsec_encryption` are "AES128", "AES192", "AES256", "DES", "DES3", "GCMAES128", "GCMAES192", "GCMAES256"
    or "None".
    EOF
  }
  validation { # connection.ipsec_policies.ipsec_integrity
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(["GCMAES128", "GCMAES192", "GCMAES256", "MD5", "SHA1", "SHA256"], ipsec_policy.ipsec_integrity)
    ]]))
    error_message = <<-EOF
    Possible values for `ipsec_integrity` are "GCMAES128", "GCMAES192", "GCMAES256", "MD5", "SHA1" or "SHA256".
    EOF
  }
  validation { # connection.ipsec_policies.pfs_group
    condition = alltrue(flatten([
      for _, v in var.local_network_gateways : [
        for _, ipsec_policy in v.connection.ipsec_policies :
        contains(["ECP256", "ECP384", "PFS1", "PFS14", "PFS2", "PFS2048", "PFS24", "PFSMM", "None"], ipsec_policy.pfs_group)
    ]]))
    error_message = <<EOF
    Possible values for `pfs_group` are "ECP256", "ECP384", "PFS1", "PFS14", "PFS2", "PFS2048", "PFS24", "PFSMM" or "None".
    EOF
  }
}

variable "vpn_clients" {
  description = <<-EOF
  VPN client configurations (IPSec point-to-site connections).

  This is a map, where each value is a VPN client configuration. Keys are just names describing a particular configuration. They
  are not being used in the actual deployment.

  Following properties are available:

  - `address_space`         - (`string`, required) the address space out of which IP addresses for vpn clients will be taken.
                              You can provide more than one address space, e.g. in CIDR notation.
  - `aad_tenant`            - (`string`, optional, defaults to `null`) AzureAD Tenant URL
  - `aad_audience`          - (`string`, optional, defaults to `null`) the client id of the Azure VPN application.
                              See Create an Active Directory (AD) tenant for P2S OpenVPN protocol connections for values
  - `aad_issuer`            - (`string`, optional, defaults to `null`) the STS url for your tenant
  - `root_certificates`     - (`map`, optional, defaults to `{}`) a map defining root certificates used to sign client 
                              certificates used by VPN clients. The key is a name of the certificate, value is the public
                              certificate in PEM format.
  - `revoked_certificates`  - (`map`, optional, defaults to `null`) a map defining revoked certificates. The key is a name of
                              the certificate, value is the thumbprint of the certificate.
  - `radius_server_address` - (`string`, optional, defaults to `null`) the address of the Radius server.
  - `radius_server_secret`  - (`string`, optional, defaults to `null`) the secret used by the Radius server.
  - `vpn_client_protocols`  - (`list(string)`, optional, defaults to `null`) list of the protocols supported by the vpn client.
                              The supported values are SSTP, IkeV2 and OpenVPN. Values SSTP and IkeV2 are incompatible with
                              the use of aad_tenant, aad_audience and aad_issuer.
  - `vpn_auth_types`        - (`list(string)`, optional, defaults to `null`) list of the vpn authentication types for
                              the Virtual Network Gateway. The supported values are AAD, Radius and Certificate.
  - `custom_routes`         - (`map`, optional, defaults to `{}`) a map defining custom routes. Each route is a list of address
                              blocks reserved for this Virtual Network (in CIDR notation). Keys in this map are only to identify
                              the CIDR blocks, values are lists of the actual address blocks.
  EOF
  default     = {}
  nullable    = false
  type = map(object({
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
    custom_routes         = optional(map(list(string)), {})
  }))
}
