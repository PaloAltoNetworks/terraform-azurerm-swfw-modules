variable "virtual_wan_name" {
  description = "The name of the Azure Virtual WAN."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Virtual WAN should exist."
  type        = string
}

variable "create" {
  description = <<-EOF
  Controls Virtual WAN creation. When set to `true`, creates the Virtual WAN, otherwise just uses a pre-existing Virtual WAN.
  EOF
  default     = true
  type        = bool
}

variable "region" {
  description = "The name of the Azure region to deploy the virtual WAN"
  type        = string
}

variable "tags" {
  description = "The map of tags to assign to all created resources."
  default     = {}
  type        = map(string)
}

variable "allow_branch_to_branch_traffic" {
  description = "Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to `true`."
  default     = true
  type        = bool
}

variable "disable_vpn_encryption" {
  description = "Optional boolean flag to specify whether VPN encryption is disabled. Defaults to `false`."
  default     = false
  type        = bool
}

variable "virtual_hubs" {
  description = <<-EOF
  Map of objects defining Virtual Hubs to manage within a Virtual WAN.

  Each object's key is an arbitrary identifier you choose (used for indexing inside the module) and each object supports the
  following attributes:

  - `name`                                   - (string, required) name of the Virtual Hub, must be unique within the Virtual WAN.
  - `create`                                 - (bool, optional, defaults to `true`) when set to `true` module will create a new
                                               Virtual Hub, when set to `false` it will reference an existing one by name.
  - `resource_group_name`                    - (string, optional) Resource Group in which to create the hub or source it from,
                                               defaults to the module's `resource_group_name` if omitted.
  - `region`                                 - (string, optional) Azure region (e.g. `"West Europe"`) for the hub, defaults to
                                               the module's `region` if omitted.
  - `address_prefix`                         - (string, required) the address prefix (CIDR) for the hub's internal subnet, must
                                               be at least `/24` (Microsoft recommends `/23`).
  - `hub_routing_preference`                 - (string, optional) routing preference for the hub, valid values are:
                                               `ExpressRoute`, `ASPath`, or `VpnGateway`.
  - `virtual_router_auto_scale_min_capacity` - (number, optional) minimum capacity for the hub's auto-scale router, Azure default
                                               is `0`.
  - `vpn_gateway`                            - (object, optional, defaults to `null`) configuration for an attached VPN Gateway,
                                               if provided this object supports the following attributes:
      - `name`                - (string, required) VPN Gateway name.  
      - `resource_group_name` - (string, optional) overrides hub's Resource Group.  
      - `region`              - (string, optional) overrides hub's Azure region.
      - `scale_unit`          - (number, optional, defaults to `1`) scale unit for the VPN Gateway.
      - `routing_preference`  - (string, optional, defaults to `"Microsoft Network"`) VPN Gateway's routing preference.
  EOF
  default     = {}
  type = map(object({
    name                                   = string
    create                                 = optional(bool, true)
    resource_group_name                    = optional(string)
    region                                 = optional(string)
    address_prefix                         = string
    hub_routing_preference                 = optional(string)
    virtual_router_auto_scale_min_capacity = optional(number)
    vpn_gateway = optional(object({
      name                = string
      resource_group_name = optional(string)
      region              = optional(string)
      scale_unit          = optional(number, 1)
      routing_preference  = optional(string, "Microsoft Network")
    }), null)
  }))
}

variable "connections" {
  description = <<-EOF
  Map of objects describing Connections within a Virtual Hub.

  Each object represents one Connection and supports the following properties:

  - `name`                      - (`string`, required) the name of the Connection, must be unique within the Virtual Hub.
  - `connection_type`           - (`string`, required) the type of Connection, use `Vnet` for Virtual Network connections.
  - `remote_virtual_network_id` - (`string`, optional) the resource ID of a remote Virtual Network.
  - `hub_key`                   - (`string`, required) the key referencing the Virtual Hub.
  - `vpn_site_key`              - (`string`, optional) the key referencing the VPN Site used in this Connection.
  - `vpn_link`                  - (`list`, optional, defaults to `[]`) list of VPN link configurations, each object supports the
                                  following attributes:
    - `vpn_link_name`                  - (`string`, required) the name of the VPN link.
    - `vpn_site_link_key`              - (`string`, required) the key referencing the VPN Site link.
    - `bandwidth_mbps`                 - (`number`, optional, defaults to `10`) bandwidth limit in Mbps.
    - `bgp_enabled`                    - (`bool`, optional, defaults to `false`) flag that enables BGP on this link.
    - `connection_mode`                - (`string`, optional, defaults to `Default`) VPN connection mode, valid values are:
                                         `Default`, `InitiatorOnly`, `ResponderOnly`.
    - `protocol`                       - (`string`, optional, defaults to `IKEv2`) VPN protocol, valid values are: `IKEv2`,
                                         `IKEv1`.
    - `ratelimit_enabled`              - (`bool`, optional, defaults to `false`) flag that enables rate limiting.
    - `route_weight`                   - (`number`, optional, defaults to `0`) routing weight for this link.
    - `shared_key`                     - (`string`, optional) pre-shared key for the VPN.
    - `local_azure_ip_address_enabled` - (`bool`, optional, defaults to `false`) flag that enables use of local Azure IP address.
    - `ipsec_policy`                   - (`object`, optional) IPSec policy configuration, following attributes are supported:
      - `dh_group`                 - (`string`, optional) Diffie-Hellman group, valid values are: `DHGroup14`, `DHGroup24`,
                                     `ECP256`, `ECP384`.
      - `ike_encryption_algorithm` - (`string`, optional) IKE encryption algorithm, valid values are: `AES128`, `AES256`,
                                     `GCMAES128`, `GCMAES256`.
      - `ike_integrity_algorithm`  - (`string`, optional) IKE integrity algorithm, valid values are: `SHA256`, `SHA384`.
      - `encryption_algorithm`     - (`string`, optional) IPSec encryption algorithm, valid values are: `AES192`, `AES128`,
                                     `AES256`, `DES`, `DES3`, `GCMAES192`, `GCMAES128`, `GCMAES256`, `None`.
      - `integrity_algorithm`      - (`string`, optional) IPSec integrity algorithm, valid values are: `SHA256`, `GCMAES128`,
                                     `GCMAES256`.
      - `pfs_group`                - (`string`, optional) Perfect Forward Secrecy algorithm, valid values are: `ECP384`,
                                     `ECP256`, `PFSMM`, `PFS1`, `PFS14`, `PFS2`, `PFS24`, `PFS2048`, `None`.
      - `sa_data_size_kb`          - (`number`, optional) Security Association size in kilobits, value must be `0` or between
                                     `1024` and `2147483647`.
      - `sa_lifetime_sec`          - (`number`, optional) Security Association lifetime in seconds.
  - `routing`                   - (`object`, optional) routing configuration, the following attributes are supported:
    - `associated_route_table_key`                - (`string`, optional) key of the associated Route Table.
    - `propagated_route_table_keys`               - (`list(string)`, optional) list of Route Table keys to propagate routes to.
    - `propagated_route_table_labels`             - (`set(string)`, optional) set of labels for propagated Route Tables.
    - `static_vnet_route_name`                    - (`string`, optional) name of the static route.
    - `static_vnet_route_address_prefixes`        - (`set(string)`, optional) set of CIDR address prefixes for static route.
    - `static_vnet_route_next_hop_ip_address`     - (`string`, optional) IP address of the next hop.
    - `static_vnet_local_route_override_criteria` - (`string`, optional, defaults to `Contains`) override criteria for the local
                                                    route, valid values are: `Contains`, `Equal`.
  EOF
  default     = {}
  type = map(object({
    name                      = string
    connection_type           = string
    hub_key                   = string
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
      associated_route_table_key                = optional(string, "default")
      propagated_route_table_keys               = optional(list(string), ["default"])
      propagated_route_table_labels             = optional(list(string), ["default"])
      static_vnet_route_name                    = optional(string)
      static_vnet_route_address_prefixes        = optional(set(string))
      static_vnet_route_next_hop_ip_address     = optional(string)
      static_vnet_local_route_override_criteria = optional(string)
    }))
  }))
  validation { # connection_name
    condition = alltrue([
      length([for _, connection in var.connections : connection.name]) ==
      length(distinct([for _, connection in var.connections : connection.name]))
    ])
    error_message = <<-EOF
    The `name` property of the connection must be unique.
    EOF
  }
  validation { # connection_type
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        contains(["Site-to-Site", "Vnet"], connection.connection_type)
      ]
    ]))
    error_message = <<-EOF
    The `connection_type` property value must be of \"Vnet\" or \"Site-to-Site\".
    EOF
  }
  validation { # vpn_link_name
    condition = alltrue([
      for _, connection in var.connections : (

        length([for vpnlink in connection.vpn_link : vpnlink.vpn_link_name]) ==
        length(distinct([for vpnlink in connection.vpn_link : vpnlink.vpn_link_name]))

      ) if connection.connection_type == "Site-to-Site"
    ])
    error_message = <<-EOF
    The `vpn_link_name` property value must be unique within each \"Site-to-Site\" connection's vpn_link list.
    EOF
  }
  validation { # vpn_link_connection_mode
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(Default|InitiatorOnly|ResponderOnly)$", vpnlink.connection_mode))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `connection_mode` property value must be of \"Default\", \"InitiatorOnly\" or \"ResponderOnly\".
    EOF
  }
  validation { # vpn_link_protocol
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(IKEv2|IKEv1)$", vpnlink.protocol))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `protocol` property value must be one of \"IKEv2\" or \"IKEv1\".
    EOF
  }
  validation { # ipsec_policy_dh_group
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(DHGroup14|DHGroup24|ECP256|ECP384)$", vpnlink.ipsec_policy.dh_group))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `dh_group` property value must be of \"DHGroup14\", \"DHGroup24\", \"ECP256\" or \"ECP384\".
    EOF
  }
  validation { # ipsec_policy_ike_encryption_algorithm
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(AES128|AES256|GCMAES128|GCMAES256)$", vpnlink.ipsec_policy.ike_encryption_algorithm))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `ike_encryption_algorithm` property value must be of \"AES128\", \"AES256\", \"GCMAES128\" or \"GCMAES256\".
    EOF
  }
  validation { # ipsec_policy_ike_integrity_algorithm
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(SHA256|SHA384)$", vpnlink.ipsec_policy.ike_integrity_algorithm))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `ike_integrity_algorithm` property value must be of \"SHA256\" or \"SHA384\".
    EOF
  }
  validation { # ipsec_policy_encryption_algorithm
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(AES128|AES256|GCMAES128|GCMAES256|None)$", vpnlink.ipsec_policy.encryption_algorithm))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `encryption_algorithm` property value must be of \"AES192\", \"AES128\", \"AES256\", \"DES\", \"DES3\", \"GCMAES192\",
    \"GCMAES128\", \"GCMAES256\", \"None\".
    EOF
  }
  validation { # ipsec_policy_integrity_algorithm
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(SHA256|GCMAES128|GCMAES256)$", vpnlink.ipsec_policy.integrity_algorithm))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `integrity_algorithm` property value must be of \"SHA256\", \"GCMAES128\" or \"GCMAES256\".
    EOF
  }
  validation { # ipsec_policy_pfs_group
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(ECP384|ECP256|PFSMM|PFS1|PFS14|PFS2|PFS24|PFS2048|None)$", vpnlink.ipsec_policy.pfs_group))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `pfs_group` property value must be one of \"ECP384\", \"ECP256\", \"PFSMM\", \"PFS1\", \"PFS14\", \"PFS2\", \"PFS24\",
    \"PFS2048\", \"None\".
    EOF
  }
  validation { # ipsec_policy_sa_data_size_kb
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          vpnlink.ipsec_policy.sa_data_size_kb == 0 ||
          (vpnlink.ipsec_policy.sa_data_size_kb >= 1024 && vpnlink.ipsec_policy.sa_data_size_kb <= 2147483647)
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `sa_data_size_kb` property value must be \"0\" or within the range of \"1024\" to \"2147483647\".
    EOF
  }
}

variable "route_tables" {
  description = <<-EOF
  Map of objects describing Route Tables to manage within a Virtual Hub.

  Each object defines a Virtual Hub Route Table configuration with attributes to control its association.

  List of available attributes for each Route Table object:

  - `name`    - (`string`, required) name of the Virtual Hub Route Table.
  - `labels`  - (`set`, optional) set of labels associated with the Route Table.
  - `hub_key` - (`string`, required) the key referencing the Virtual Hub.
  EOF
  default     = {}
  type = map(object({
    name    = string
    labels  = optional(set(string))
    hub_key = string
  }))
}

variable "vpn_sites" {
  description = <<-EOF
  Map of objects describing VPN Sites to be configured within the Azure environment.

  Each object defines a single VPN Site and supports the following properties:

  - `name`                - (`string`, required) the unique name of the VPN Site.
  - `resource_group_name` - (`string`, optional) the name of the Resource Group for the VPN Site.
  - `region`              - (`string`, optional) the Azure region where the VPN Site is located.
  - `address_cidrs`       - (`set(string)`, required) set of IPv4 CIDR blocks associated with the VPN Site.
  - `link`                - (`list(object)`, optional, defaults to `[]`) list of individual link configurations, each object
                            supports the following properties:
    - `name`          - (`string`, required) the name of the link.
    - `ip_address`    - (`string`, optional) the public IP address of the link.
    - `fqdn`          - (`string`, optional) the fully qualified domain name for the link.
    - `provider_name` - (`string`, optional) the name of the service provider.
    - `speed_in_mbps` - (`number`, optional, defaults to `0`) the link speed in Mbps.
  EOF
  default     = {}
  type = map(object({
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
  validation { # vpn_site_name
    condition = alltrue([
      length([for _, vpnsite in var.vpn_sites : vpnsite.name]) ==
      length(distinct([for _, vpnsite in var.vpn_sites : vpnsite.name]))
    ])
    error_message = <<-EOF
    The `name` property of the VPN site must be unique.
    EOF
  }
  validation { # address_cidrs
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : (
        vpnsite != null && try(vpnsite.address_cidrs, null) != null ?
        [for cidr in vpnsite.address_cidrs : can(
          regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(3[0-2]|[12]?[0-9])$", cidr)
        )] : []
      )
    ]))
    error_message = <<-EOF
    Each `address_cidrs` property value must be a valid IPv4 CIDR in x.x.x.x/n format.
    EOF
  }
  validation { # link key
    condition = alltrue([
      for _, vpnsite in var.vpn_sites : (
        length(keys(vpnsite.link)) ==
        length(distinct(keys(vpnsite.link)))
      )
    ])
    error_message = <<-EOF
    Each link name within a VPN Site must be unique.
    EOF
  }
  validation { # ip_address
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : [
        for _, sitelink in vpnsite.link : [
          sitelink.ip_address == null || can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", sitelink.ip_address))
        ]
      ]
    ]))
    error_message = <<-EOF
    The `ip_address` property value must be a valid IPv4 address in the x.x.x.x format, with each octet ranging from 0 to 255.
    EOF
  }
}
