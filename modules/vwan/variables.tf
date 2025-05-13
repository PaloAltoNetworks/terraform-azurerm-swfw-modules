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
  description = "Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true."
  default     = true
  type        = bool
}

variable "disable_vpn_encryption" {
  description = "Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false."
  default     = false
  type        = bool
}

variable "virtual_hubs" {
  description = <<-EOF
Map of objects defining Virtual Hubs to manage within a Virtual WAN.

Each entry's key is an arbitrary identifier you choose (used for indexing
inside the module), and each object supports:

- `name`                         - (string, required) the name of the Virtual Hub. Must be unique within the Virtual WAN.
- `create`                       - (bool, optional, defaults to `true`) when true, the module will create a new Virtual Hub. 
                                    When false,it will reference an existing one by name.
- `resource_group_name`          - (string, optional) the Resource Group in which to create or locate the hub. Defaults
                                    to the module’s `resource_group_name` if omitted.
- `region`                       - (string, optional) azure region (e.g. `"West Europe"`) for the hub. Defaults to the
                                    module’s `region` if omitted.
- `address_prefix`               - (string, required)the address prefix (CIDR) for the hub’s internal subnet. Must be
                                    at least `/24` (Microsoft recommends `/23`).
- `hub_routing_preference`       - (string, optional)routing preference for the hub. Valid values:`ExpressRoute`, `ASPath`, or `VpnGateway`.
- `virtual_router_auto_scale_min_capacity` - (number, optional) minimum capacity for the hub’s auto-scale router. Defaults to `0`.
- `vpn_gateway`                  - (object, optional, defaults to `null`)  
    Configuration for an attached VPN Gateway. If provided, this object supports:
    - `name`                - (string, required) gateway name.  
    - `resource_group_name` - (string, optional) overrides hub RG.  
    - `region`              - (string, optional) overrides hub region.  
    - `scale_unit`          - (number, optional, defaults to `1`)  
    - `routing_preference`  - (string, optional, defaults to `"Microsoft Network"`)  
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
Map of objects describing connections within a Virtual Hub.

Each object represents one connection, and supports the following properties:

- `name`                       - (`string`, required) the name of the connection. Must be unique within the Virtual Hub.
- `connection_type`            - (`string`, required) the type of connection. Use `Vnet` for Virtual Network connections.
- `remote_virtual_network_id`  - (`string`, optional) the resource ID of a remote Virtual Network.
- `hub_key`                    - (`string`, required) the key referencing the Virtual Hub.
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
EOF

  default = {}
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
    The `connection_type` must be one of \"Vnet\" or \"Site-to-Site\".
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
    The `vpn_link_name` property must be unique within each \"Site-to-Site\" connection's vpn_link list.
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
    The `connection_mode` must be one of \"Default\", \"InitiatorOnly\" or \"ResponderOnly\".
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
    The `protocol` must be one of \"IKEv2\" or \"IKEv1\".
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
    The `dh_group` must be one of \"DHGroup14\", \"DHGroup24\", \"ECP256\" or \"ECP384\".
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
    The `ike_encryption_algorithm` must be one of \"AES128\", \"AES256\", \"GCMAES128\" or \"GCMAES256\".
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
    The `ike_integrity_algorithm` must be one of \"SHA256\" or \"SHA384\".
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
    The `encryption_algorithm` must be one of \"AES192\", \"AES128\", \"AES256\", \"DES\", \"DES3\", \"GCMAES192\", \"GCMAES128\",
    \"GCMAES256\", \"None\" .
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
    The `integrity_algorithm` must be one of \"SHA256\", \"GCMAES128\" or \"GCMAES256\".
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
    The `pfs_group` must be one of \"ECP384\", \"ECP256\", \"PFSMM\", \"PFS1\", \"PFS14\", \"PFS2\", \"PFS24\", \"PFS2048\",
    \"None\" .
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
    The `sa_data_size_kb` must be 0 or within the range of 1024 to 2147483647.
    EOF
  }
}

variable "route_tables" {
  description = <<-EOF
  Map of objects describing route tables to manage within a Virtual Hub.

  Each entry defines a Virtual Hub Route Table configuration with attributes to control its association.

  List of available attributes for each route table entry:

  - `name`                - (`string`, required) name of the Virtual Hub Route Table.
  - `labels`              - (`set`, optional) Set of labels associated with the Route Table.
  - `hub_key`             - (`string`, required) the key referencing the Virtual Hub.

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
EOF

  default = {}
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

  validation { # vpn_site_name uniqueness
    condition = alltrue([
      length([for _, vpnsite in var.vpn_sites : vpnsite.name]) ==
      length(distinct([for _, vpnsite in var.vpn_sites : vpnsite.name]))
    ])
    error_message = "The `name` property of the VPN site must be unique."
  }

  validation {
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : (
        vpnsite != null && try(vpnsite.address_cidrs, null) != null ?
        [for cidr in vpnsite.address_cidrs : can(
          regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(3[0-2]|[12]?[0-9])$", cidr)
        )] : []
      )
    ]))
    error_message = "Each `address_cidrs` must be a valid IPv4 CIDR in x.x.x.x/n format."
  }


  validation { # link_name uniqueness within each VPN site
    condition = alltrue([
      for _, vpnsite in var.vpn_sites : (
        length(keys(vpnsite.link)) ==
        length(distinct(keys(vpnsite.link)))
      )
    ])
    error_message = "Each link name within a VPN site must be unique."
  }

  validation { # ip_address validation
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : [
        for _, sitelink in vpnsite.link : [
          sitelink.ip_address == null || can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", sitelink.ip_address))
        ]
      ]
    ]))
    error_message = "The `ip_address` must be a valid IPv4 address in the format x.x.x.x, with each octet ranging from 0 to 255, if provided."
  }
}