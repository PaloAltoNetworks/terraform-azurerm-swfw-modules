# Main resource
variable "name" {
  description = "The name of the Virtual Network Gateway."
  type        = string
}

# Common settings
variable "resource_group_name" {
  description = "The name of the Resource Group to use."
  type        = string
}

variable "location" {
  description = "The name of the Azure region to deploy the resources in."
  type        = string
}

variable "tags" {
  description = "The map of tags to assign to all created resources."
  default     = {}
  type        = map(string)
}

variable "virtual_network_gateway" {
  description = <<-EOF
  A map containing the basic Virtual Network Gateway configuration.

  You configure the size, capacity and capabilities with 4 parameters that heavily depend on each other. Please follow the table
  below for details on available combinations:

  # REFACTOR add here a table with possible config combinations

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

  EOF
  type = object({
    type          = optional(string, "Vpn")
    vpn_type      = optional(string, "RouteBased")
    sku           = optional(string, "Basic")
    active_active = optional(bool, false)
    generation    = optional(string, "Generation1")
    custom_routes = optional(map(list(string)), {})
  })
  validation { # type
    condition     = contains(["Vpn", "ExpressRoute"], var.virtual_network_gateway.type)
    error_message = <<-EOF
    The `virtual_network_gateway.type` property can take one of the following values: "Vpn" or "ExpressRoute".
    EOF
  }
  validation { # vpn_type
    condition     = contains(["RouteBased", "PolicyBased"], var.virtual_network_gateway.vpn_type)
    error_message = <<-EOF
    The `virtual_network_gateway.vpn_type` property can take one of the following values: "RouteBased" or "PolicyBased".
    EOF
  }
  validation { # generation
    condition     = contains(["Generation1", "Generation2", "None"], var.virtual_network_gateway.generation)
    error_message = <<-EOF
    The `virtual_network_gateway.generation` property can take one of the following values: "Generation1" or "Generation2"
    or "None".
    EOF
  }
}

variable "network" {
  description = <<-EOF
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

  EOF
  type = object({
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
}

variable "azure_bgp_peer_addresses" { # do not delete this one
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
  type        = map(string)
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
      secondary_peering_addresses = optional(object({ # REFACTOR add a precondition like for network configuration
        name               = string
        apipa_address_keys = list(string)
        default_addresses  = optional(list(string))
      }))
    }))
  })
  validation { # configuration
    condition     = (var.bgp.enable && var.bgp.configuration != null) || (!var.bgp.enable && var.bgp.configuration == null)
    error_message = "The `configuration` property is required only when `enabled` is set to `true`."
  }
  validation { # configuration.peer_weight
    condition     = var.bgp.configuration.peer_weight == null ? true : var.bgp.configuration.peer_weight >= 0 && var.bgp.configuration.peer_weight <= 100
    error_message = "Possible values for `peer_weight` are between 0 and 100."
  }
}



# variable "sku" {
#   description = <<-EOF
#   Configuration of the size and capacity of the virtual network gateway.

#   Valid option depends on the type, vpn_type and generation arguments. A PolicyBased gateway only supports the Basic SKU.
#   Further, the UltraPerformance SKU is only supported by an ExpressRoute gateway.
#   EOF
#   default     = "Basic"
#   nullable    = false
#   type        = string
#   validation {
#     condition     = contains(["Basic", "Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.sku)
#     error_message = "Valid options are Basic, Standard, HighPerformance, UltraPerformance, ErGw1AZ, ErGw2AZ, ErGw3AZ, VpnGw1, VpnGw2, VpnGw3, VpnGw4,VpnGw5, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ,VpnGw4AZ and VpnGw5AZ and depend on the type, vpn_type and generation arguments"
#   }
# }



# variable "zones" {
#   description = <<-EOF
#   After provider version 3.x you need to specify in which availability zone(s) you want to place IP.

#   For zone-redundant with 3 availability zones in current region value will be:
#   ```["1","2","3"]```
#   EOF
#   default     = null
#   type        = list(string)
#   validation {
#     condition = var.zones == null || (var.zones != null ? (
#       length(var.zones) == 3 && length(setsubtract(var.zones, ["1", "2", "3"])) == 0
#     ) : true)
#     error_message = "No zones or all 3 zones are expected"
#   }
# }


variable "vpn_clients" {
  description = <<-EOF
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
  }))
}

variable "local_network_gateways" {
  description = <<-EOF
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

  EOF
  type = map(object({
    name = string
    remote_bgp_settings = optional(list(object({ # REFACTOR: check how many items you can have here, does it depend on active-active? maybe this should also be map to avoid confusion (if max 2 are allowed)
      asn                 = string
      bgp_peering_address = string
      peer_weight         = optional(number)
    })), [])
    gateway_address = optional(string)
    address_space   = optional(list(string), [])
    custom_bgp_addresses = optional(list(object({ # REFACTOR: check how many items you can have here, does it depend on active-active? maybe this should also be map to avoid confusion (if max 2 are allowed)
      primary_key   = string
      secondary_key = optional(string)
    })), [])
    connection = object({
      name = string
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
