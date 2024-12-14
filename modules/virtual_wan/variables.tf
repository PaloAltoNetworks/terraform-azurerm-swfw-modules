variable "create_virtual_wan" {
  description = <<-EOF
  Controls Virtual Wan creation.
  
  When set to `true`, creates the Virtual Wan, otherwise just use a pre-existing Virtual Wan.
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

variable "virtual_hubs" {
  description = <<-EOF
  Map of objects describing virtual hubs to manage.
  
  Each entry represents a Virtual Hub configuration with attributes that define its properties. 
  By default, the Virtual Hubs specified here will be created. If `create_virtual_hub` is set to `false` 
  for a hub entry, the module will not create the Virtual Hub; instead, it will reference existing resources.
  
  List of available attributes for each virtual hub entry:

  - `name`                   - (`string`, required) The name of the Virtual Hub.
  - `create_virtual_hub`     - (`bool`, optional, defaults to `true`) Determines whether to create the Virtual Hub. 
                               If set to `false`, existing resources will be referenced.
  - `address_prefix`         - (`string`, required when `create_virtual_hub = true`) The address prefix for the Virtual Hub.
                               Must be a subnet no smaller than /24 (Azure recommends /23).
  - `region`                 - (`string`, optional) The Azure location for the Virtual Hub.
  - `resource_group_name`    - (`string`, optional) Name of the Resource Group where the Virtual Hub should exist.
  - `hub_routing_preference` - (`string`, optional, defaults to `ExpressRoute`) Hub routing preference. 
                               Acceptable values are `ExpressRoute`, `ASPath`, and `VpnGateway`.
  - `virtual_wan_id`         - (`string`, optional) ID of a Virtual WAN within which the Virtual Hub should be created.
                               If omitted, it will connect to a local default virtual wan.
  - `tags`                   - (`map`, optional) Key-value pairs to assign as tags to the Virtual Hub.
                               **Note!** To be compatible with the `azurerm_palo_alto_virtual_network_appliance` resource, 
                               include the tag `"hubSaaSPreview" = "true"`.
  EOF
  default     = {}
  type = map(object({
    name                   = string
    create_virtual_hub     = optional(bool, true)
    resource_group_name    = optional(string)
    address_prefix         = optional(string)
    region                 = optional(string)
    hub_routing_preference = optional(string, "ExpressRoute")
    virtual_wan_id         = optional(string)
    tags                   = optional(map(string))
  }))

  validation { #address_prefix
    condition = alltrue(flatten([
      for _, vh in var.virtual_hubs : [
        can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-1]?[0-9]|2[0-4])$", vh.address_prefix))
      ]
    ]))
    error_message = <<-EOF
    The `address_prefix` must be a valid IPv4 CIDR with a subnet mask between /0 and /24.
    EOF
  }

  validation { #hub_routing_preference
    condition = alltrue(flatten([
      for _, vh in var.virtual_hubs : [
        can(regex("^(ExpressRoute|ASPath|VpnGateway)$", vh.hub_routing_preference))
      ]
    ]))
    error_message = <<-EOF
    The `hub_routing_preference` must be one of 'ExpressRoute', 'ASPath', or 'VpnGateway'.
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
  - `virtual_hub_key`     - (`string`, optional, required if `create_route_table = true`) ID of the Virtual Hub in which to create 
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
    create_route_table  = optional(bool, false)
    name                = string
    virtual_hub_key     = optional(string)
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

  - `name`                       - (`string`, required) Name of the Connection, unique within the Virtual Hub. 
  - `virtual_hub_key`            - (`string`, required) ID of the Virtual Hub for this connection. 
  - `remote_virtual_network_key` - (`string`, required) ID of the Virtual Network to connect to. 
  - `connection_type`            - (`string`, required) Type of connection; set to "Vnet" for Virtual Network connections.
  - `vpn_gateway_key`            - (`string`, optional) ID of the VPN Gateway associated with this connection.
  - `vpn_site_key`               - (`string`, optional) ID of the VPN Site to connect to if applicable.
  - `vpn_link`                   - (`list`, optional) A list of VPN link configurations for Site-to-Site VPN connections, 
                                   each with several attributes (see below).
  - `routing`                    - (`map`, optional) Routing configuration block (see below for available attributes).

  **VPN Link Configuration Block**:
  The `vpn_link` block is required for Site-to-Site connections and supports the following attributes:

  - `vpn_link_name`                  - (`string`, required) Name of the VPN link, must be unique within each Site-to-Site 
                                       connection's VPN link list.
  - `vpn_site_link_index`            - (`number`, required) The index number for the VPN site link.
  - `bandwidth_mbps`                 - (`number`, optional) Bandwidth limit in Mbps; defaults to `10`.
  - `bgp_enabled`                    - (`bool`, optional) Enables BGP; defaults to `false`.
  - `connection_mode`                - (`string`, optional) Connection mode; valid values are `"Default"`, `"InitiatorOnly"`, 
                                        `"ResponderOnly"`. Defaults to `"Default"`.
  - `protocol`                       - (`string`, optional) Protocol used; valid values are `"IKEv2"`, `"IKEv1"`. 
                                       Defaults to `"IKEv2"`.
  - `ratelimit_enabled`              - (`bool`, optional) Enables rate limiting; defaults to `false`.
  - `route_weight`                   - (`number`, optional) Weight for routing; defaults to `0`.
  - `shared_key`                     - (`string`, optional) Shared key for the connection.
  - `local_azure_ip_address_enabled` - (`bool`, optional) Enables local Azure IP address; defaults to `false`.
  - `ipsec_policy`                   - (`object`, optional) IPsec policy settings with required attributes:
    - `dh_group`                 - (`string`) Diffie-Hellman group, must be one of `"DHGroup14"`, `"DHGroup24"`, `"ECP256"` 
                                    or `"ECP384"`.
    - `ike_encryption_algorithm` - (`string`) IKE encryption algorithm, must be one of `"AES128"`, `"AES256"`, `"GCMAES128"`, 
                                    `"GCMAES256"`.
    - `ike_integrity_algorithm`  - (`string`) IKE integrity algorithm, must be `"SHA256"` or `"SHA384"`.
    - `encryption_algorithm`     - (`string`) Encryption algorithm, valid values are `"AES192"`, `"AES128"`, `"AES256"`, `"DES"`, 
                                    `"DES3"`, `"GCMAES192"`, `"GCMAES128"`, `"GCMAES256"`, `"None"`.
    - `integrity_algorithm`      - (`string`) Integrity algorithm, must be one of `"SHA256"`, `"GCMAES128"`, or `"GCMAES256"`.
    - `pfs_group`                - (`string`) Perfect Forward Secrecy group, must be one of `"ECP384"`, `"ECP256"`, `"PFSMM"`, 
                                    `"PFS1"`, `"PFS14"`, `"PFS2"`, `"PFS24"`, `"PFS2048"`, or `"None"`.
    - `sa_data_size_kb`          - (`number`) Security Association data size, must be `0` or within the range `1024 - 2147483647`.
    - `sa_lifetime_sec`          - (`number`) Security Association lifetime in seconds.

  **Routing Configuration Block**:
  The `routing` block configures routing for the connection and supports the following attributes:

  - `associated_route_table_key`                - (`string`, optional) Associates the connection with a route table.
  - `propagated_route_table_keys`               - (`list`, optional) Propagates the connection to specified route tables.
  - `propagated_route_table_labels`             - (`set`, optional) Labels of propagated route tables.
  - `static_vnet_route_name`                    - (`string`, optional) Name for this static route.
  - `static_vnet_route_address_prefixes`        - (`set`, optional) List of CIDR prefixes for the route.
  - `static_vnet_route_next_hop_ip_address`     - (`string`, optional) IP address for the next hop in the route.
  - `static_vnet_local_route_override_criteria` - (`string`, optional) Criteria for overriding local routes; values can be 
                                                   `Contains` or `Equal`. Defaults to `Contains`.
  EOF
  default     = {}
  type = map(object({
    name                       = string
    connection_type            = string
    virtual_hub_key            = optional(string)
    remote_virtual_network_key = optional(string)
    vpn_gateway_key            = optional(string)
    vpn_site_key               = optional(string)
    vpn_link = optional(list(object({
      vpn_link_name                  = string
      vpn_site_link_index            = number
      bandwidth_mbps                 = optional(number, 10)
      bgp_enabled                    = optional(bool, false)
      connection_mode                = optional(string, "Default")
      protocol                       = optional(string, "IKEv2")
      ratelimit_enabled              = optional(bool, false)
      route_weight                   = optional(number, 0)
      shared_key                     = optional(string)
      local_azure_ip_address_enabled = optional(bool, false)
      ipsec_policy = optional(object({
        dh_group                 = string
        ike_encryption_algorithm = string
        ike_integrity_algorithm  = string
        encryption_algorithm     = string
        integrity_algorithm      = string
        pfs_group                = string
        sa_data_size_kb          = number
        sa_lifetime_sec          = number
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

  validation { #connection_name
    condition = alltrue([
      length([for _, connection in var.connections : connection.name]) ==
      length(distinct([for _, connection in var.connections : connection.name]))
    ])
    error_message = <<-EOF
    The `name` property of the connection must be unique.
    EOF
  }

  validation { #connection_type
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        can(regex("^(Site-to-Site|Vnet)$", connection.connection_type))
      ]
    ]))
    error_message = <<-EOF
    The `connection_type` must be one of 'Vnet' or 'Site-to-Site'.
    EOF
  }

  validation { #vpn_link_name
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

  validation { #vpn_link_connection_mode
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

  validation { #vpn_link_protocol
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

  validation { #ipsec_policy_dh_group
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

  validation { #ipsec_policy_ike_encryption_algorithm
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

  validation { #ipsec_policy_ike_integrity_algorithm
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

  validation { #ipsec_policy_encryption_algorithm
    condition = alltrue(flatten([
      for _, connection in var.connections : [
        for vpnlink in connection.vpn_link : [
          can(regex("^(AES192|AES128|AES256|DES|DES3|GCMAES192|GCMAES128|GCMAES256|None)$", vpnlink.ipsec_policy.encryption_algorithm))
      ]] if connection.connection_type == "Site-to-Site"
    ]))
    error_message = <<-EOF
    The `encryption_algorithm` must be one of 'AES192', 'AES128', 'AES256', 'DES', 'DES3', 'GCMAES192', 'GCMAES128', 'GCMAES256', 'None' .
    EOF
  }

  validation { #ipsec_policy_integrity_algorithm
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

  validation { #ipsec_policy_pfs_group
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

  validation { #ipsec_policy_sa_data_size_kb
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

variable "vpn_gateways" {
  description = <<-EOF
  Map of objects describing VPN Gateways to manage within a Virtual Hub.

  List of available attributes for each VPN Gateway entry:

  - `name`                - (`string`, required) Name of the VPN Gateway. Must be unique across all defined VPN Gateways.
  - `region`              - (`string`, optional) The Azure location where the VPN Gateway should be deployed.
  - `resource_group_name` - (`string`, optional) Name of the Resource Group where the VPN Gateway should be created.
  - `virtual_hub_key`     - (`string`, required) The ID of the Virtual Hub to which the VPN Gateway is associated. 
  - `scale_unit`          - (`number`, optional) Specifies the scale unit for the VPN Gateway, impacting its performance and 
                            throughput. Defaults to `1`.
  - `routing_preference`  - (`string`, optional) Specifies the routing preference. Valid values are `"Microsoft Network"`
                            and `"Internet"`.
  - `tags`                - (`map`, optional) Key-value pairs for tagging the VPN Gateway for identification and organizational 
                            purposes.

  EOF
  default     = {}
  type = map(object({
    name                = string
    region              = optional(string)
    resource_group_name = optional(string)
    virtual_hub_key     = string
    scale_unit          = optional(number, 1)
    routing_preference  = optional(string, "Microsoft Network")
    tags                = optional(map(string))
  }))

  validation { #vpn_gateway_name
    condition = alltrue([
      length([for _, vpngw in var.vpn_gateways : vpngw.name]) ==
      length(distinct([for _, vpngw in var.vpn_gateways : vpngw.name]))
    ])
    error_message = <<-EOF
    The `name` property of the VPN Gateway must be unique.
    EOF
  }

  validation { #routing_preference
    condition = alltrue(flatten([
      for _, vpngw in var.vpn_gateways : [
        can(regex("^(Microsoft Network|Internet)$", vpngw.routing_preference))
      ]
    ]))
    error_message = <<-EOF
    The `routing_preference` must be one of 'Microsoft Network' or 'Internet'.
    EOF
  }
}


variable "vpn_sites" {
  description = <<-EOF
  Map of objects describing VPN sites to be configured within the Azure environment.

  Each entry represents a VPN site with its specific configuration settings, allowing users to define essential details 
  about the site such as its name, region, resource group, address prefixes, and associated links.

  List of available attributes for each VPN site entry:

  - `name`                - (`string`, required) The unique name of the VPN site.
  - `region`              - (`string`, optional) The Azure region where the VPN site is located.
  - `resource_group_name` - (`string`, optional) The name of the resource group containing the VPN site.
  - `address_cidrs`       - (`set`, optional) A set of valid IPv4 CIDR blocks associated with the VPN site.
  
  **Link Configuration Block**:
  The `link` block represents individual connections for the VPN site and supports the following attributes:
  
  - `name`          - (`string`, required) The name of the link.
  - `ip_address`    - (`string`, optional) The public IP address of the link, if applicable.
  - `fqdn`          - (`string`, optional) Fully Qualified Domain Name for the link.
  - `provider_name` - (`string`, optional) The name of the service provider associated with the link.
  - `speed_in_mbps` - (`number`, optional) The speed of the link in Mbps; defaults to `0`.
  EOF
  default     = {}
  type = map(object({
    name                = string
    region              = optional(string)
    resource_group_name = optional(string)
    address_cidrs       = optional(set(string))
    link = optional(list(object({
      name          = string
      ip_address    = optional(string)
      fqdn          = optional(string)
      provider_name = optional(string)
      speed_in_mbps = optional(number, 0)
    })), [])
  }))

  validation { #vpn_site_name
    condition = alltrue([
      length([for _, vpnsite in var.vpn_sites : vpnsite.name]) ==
      length(distinct([for _, vpnsite in var.vpn_sites : vpnsite.name]))
    ])
    error_message = <<-EOF
    The `name` property of the vpn site must be unique.
    EOF
  }

  validation { #address_cidrs
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : [
        for ac in vpnsite.address_cidrs : [
          can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(3[0-2]|[12]?[0-9])$", ac))
      ]]
    ]))
    error_message = <<-EOF
    The `address_cidrs` must be a valid IPv4 CIDR in the format x.x.x.x/n, where n is between 0 and 32.
    EOF
  }

  validation { #link_name
    condition = alltrue([
      for _, vpnsite in var.vpn_sites : (
        length([for sitelink in vpnsite.link : sitelink.name]) ==
        length(distinct([for sitelink in vpnsite.link : sitelink.name]))
      )
    ])
    error_message = <<-EOF
    The `link_name` property must be unique within each vpn site
    EOF
  }

  validation { # ip_address
    condition = alltrue(flatten([
      for _, vpnsite in var.vpn_sites : [
        for sitelink in vpnsite.link : [
          sitelink.ip_address == null || can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", sitelink.ip_address))
        ]
      ]
    ]))
    error_message = <<-EOF
    The `ip_address` must be a valid IPv4 address in the format x.x.x.x, with each octet ranging from 0 to 255, if provided.
    EOF
  }
}

variable "remote_virtual_network_ids" {
  description = "The map of virtual networks ids to connect to hub"
  default     = {}
  type        = map(string)
}






