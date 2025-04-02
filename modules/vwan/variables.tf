variable "create_virtual_wan" {
  description = <<-EOF
  Controls Virtual Wan creation. When set to `true`, creates the Virtual Wan, otherwise just use a pre-existing Virtual Wan.
  EOF
  default     = true
  type        = bool
}

variable "name" {
  description = "The name of the Azure Virtual Wan."
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

variable "disable_vpn_encryption" {
  description = "Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false."
  default     = false
  type        = bool
}

variable "allow_branch_to_branch_traffic" {
  description = "Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true."
  default     = true
  type        = bool
}

variable "tags" {
  description = "The map of tags to assign to all created resources."
  default     = {}
  type        = map(string)
}

variable "remote_virtual_network_ids" {
  description = "The map of virtual networks ids to connect to hub"
  default     = {}
  type        = map(string)
}

variable "virtual_hubs" {
  description = <<-EOF
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
  - `tags`                   - (`map`, optional) key-value pairs to assign as tags to the Virtual Hub.
 EOF
  default     = {}
  type = map(object({
    name                   = string
    create_virtual_hub     = optional(bool, true)
    resource_group_name    = optional(string)
    address_prefix         = optional(string)
    region                 = optional(string)
    hub_routing_preference = optional(string, "ExpressRoute")
    tags                   = optional(map(string))
  }))

  validation { # address_prefix
    condition = alltrue(flatten([
      for _, vh in var.virtual_hubs : [
        can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-1]?[0-9]|2[0-4])$", vh.address_prefix))
      ]
    ]))
    error_message = <<-EOF
    The `address_prefix` must be a valid IPv4 CIDR with a subnet mask between /0 and /24.
    EOF
  }

  validation { # hub_routing_preference
    condition = alltrue(flatten([
      for _, vh in var.virtual_hubs : [
        can(regex("^(ExpressRoute|ASPath|VpnGateway)$", vh.hub_routing_preference))
      ]
    ]))
    error_message = <<-EOF
    The `hub_routing_preference` must be one of \"ExpressRoute"\, \"ASPath"\, or \"VpnGateway"\.
    EOF
  }
}
variable "route_tables" {
  description = <<-EOF
  Map of objects describing route tables to manage within a Virtual Hub.

  Each entry defines a Virtual Hub Route Table configuration with attributes to control its creation and association.
  If `create_route_table` is set to `true`, the module will create a new route table. If set to `false`, 
  the module will source an existing route table from the specified Virtual Hub.

  List of available attributes for each route table entry:

  - `name`                - (`string`, required) Name of the Virtual Hub Route Table.
  - `create_route_table`  - (`bool`, required) Indicates whether to create a new route table. 
                            If `false`, the module will reference an existing route table.
  - `virtual_hub_id`     - (`string`, optional, required if `create_route_table = true`) ID of the Virtual Hub in which to create 
                            the route table.
  - `labels`              - (`set`, optional, required if `create_route_table = true`) Set of labels associated with the route 
                            table.
  - `virtual_hub_name`    - (`string`, optional, required if `create_route_table = false`) Name of the existing Virtual Hub Route 
                            Table.
  - `resource_group_name` - (`string`, optional, required if `create_route_table = false`) Name of the Resource Group where the 
                            existing Virtual Hub Route Table is located.
  EOF
  default     = {}
  type = map(object({
    name                = string
    create_route_table  = optional(bool, true)
    virtual_hub_id      = optional(string)
    labels              = optional(set(string))
    virtual_hub_name    = optional(string)
    resource_group_name = optional(string)
  }))
}


variable "connections" {
  description = <<-EOF
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
  EOF
  default     = {}
  type = map(object({
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

  validation { # connection_name
    condition = alltrue([
      length([for _, connection in var.connections : connection.name]) ==
      length(distinct([for _, connection in var.connections : connection.name]))
    ])
    error_message = <<-EOF
    The `name` property of the connection must be unique.
    EOF
  }

  validation { #connection_type
    condition = alltrue([
      for _, connection in var.connections :
      contains(["Site-to-Site", "Vnet"], connection.connection_type)
    ])
    error_message = <<-EOF
  The `connection_type` must be one of 'Vnet' or 'Site-to-Site'.
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
    The `vpn_link_name` property must be unique within each 'Site-to-Site' connection's vpn_link list.
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
    The `connection_mode` must be one of 'Default', 'InitiatorOnly' or 'ResponderOnly'.
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
    The `protocol` must be one of 'IKEv2' or 'IKEv1'.
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
    The `dh_group` must be one of 'DHGroup14', 'DHGroup24', 'ECP256' or 'ECP384'.
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
    The `ike_encryption_algorithm` must be one of 'AES128', 'AES256', 'GCMAES128' or 'GCMAES256'.
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
    The `ike_integrity_algorithm` must be one of 'SHA256' or 'SHA384'.
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
    The `encryption_algorithm` must be one of 'AES192', 'AES128', 'AES256', 'DES', 'DES3', 'GCMAES192', 'GCMAES128', 'GCMAES256', 'None' .
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
    The `integrity_algorithm` must be one of 'SHA256', 'GCMAES128' or 'GCMAES256'.
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
    The `pfs_group` must be one of 'ECP384', 'ECP256', 'PFSMM', 'PFS1', 'PFS14', 'PFS2', 'PFS24', 'PFS2048', 'None' .
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

variable "vpn_gateway" {
  description = <<-EOF
  Object describing a VPN Gateway to be managed within a Virtual Hub.

  List of available attributes:

  - `name`                - (`string`, required) name of the VPN Gateway.
  - `region`              - (`string`, optional) the Azure location where the VPN Gateway should be deployed.
  - `resource_group_name` - (`string`, optional) name of the Resource Group where the VPN Gateway should be created.
  - `virtual_hub_id`     - (`string`, required) the ID of the Virtual Hub to which the VPN Gateway is associated. 
  - `scale_unit`          - (`number`, optional) specifies the scale unit for the VPN Gateway, impacting its performance and 
                            throughput. Defaults to `1`.
  - `routing_preference`  - (`string`, optional) specifies the routing preference. Valid values are `"Microsoft Network"`
                            and `"Internet"`.
  - `tags`                - (`map`, optional) key-value pairs for tagging the VPN Gateway for identification and organizational 
                            purposes.

  EOF
  default     = null
  type = object({
    name                = string
    region              = optional(string)
    resource_group_name = optional(string)
    virtual_hub_id      = string
    scale_unit          = optional(number, 1)
    routing_preference  = optional(string, "Microsoft Network")
    tags                = optional(map(string))
  })
}



variable "vpn_sites" {
  description = <<-EOF
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
  EOF
  default     = {}
  type = map(object({
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

  validation { # vpn_site_name uniqueness
    condition = alltrue([
      length([for _, vpnsite in var.vpn_sites : vpnsite.name]) ==
      length(distinct([for _, vpnsite in var.vpn_sites : vpnsite.name]))
    ])
    error_message = "The `name` property of the VPN site must be unique."
  }

  validation { # address_cidrs validation
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : [
        for ac in vpnsite.address_cidrs : [
          can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(3[0-2]|[12]?[0-9])$", ac))
      ]]
    ]))
    error_message = "The `address_cidrs` must be a valid IPv4 CIDR in the format x.x.x.x/n, where n is between 0 and 32."
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







