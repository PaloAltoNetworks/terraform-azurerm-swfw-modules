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

variable "virtual_hub_id" {
  description = "The ID of the Azure Virtual Hub used for connecting various network resources."
  default     = null
  type        = string
}

variable "virtual_network_id" {
  description = "The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw."
  default     = null
  type        = string
}

variable "trusted_subnet_id" {
  description = "The ID of the subnet designated for trusted resources within the virtual network."
  default     = null
  type        = string
}

variable "untrusted_subnet_id" {
  description = "The ID of the subnet designated for untrusted resources within the virtual network."
  default     = null
  type        = string
}

variable "attachment_type" {
  description = <<-EOF
  Defines how the cngfw (Cloud NGFW) is attached.

  - When set to `vnet`, the cngfw is used to filter traffic between trusted and untrusted subnets within a Virtual Network (VNet).
  - When set to `vwan`, the cngfw is used to filter traffic within the Azure Virtual Wan.
  EOF
  type        = string

  validation {
    condition     = var.attachment_type == "vnet" || var.attachment_type == "vwan"
    error_message = "The attachment_type must be either 'vnet' or 'vwan'."
  }
}

variable "management_mode" {
  description = <<-EOF
  Defines how the cngfw is managed.

  - When set to `panorama`, the cngfw policies are managed through Panorama.
  EOF
  type        = string

  validation {
    condition     = var.management_mode == "panorama"
    error_message = "The management_mode must be set to 'panorama'."
  }
}

variable "palo_alto_virtual_appliance" {
  description = <<-EOF
  Map of objects describing Palo Alto Virtual Appliance instances.

  Each object in the map has the following properties:

  - `palo_alto_virtual_appliance_name` - (`string`, required) The name of the Palo Alto Virtual Appliance instance.
  
  EOF
  nullable    = false
  default     = {}
  type = map(object({
    palo_alto_virtual_appliance_name = string
  }))
}

variable "cngfw_config" {
  description = <<-EOF
  Map of objects describing Palo Alto Next Generation Firewalls (cngfw).

  List of available properties:

  - `cngfw_name`                      - (`string`, required) The name of the Palo Alto Next Generation Firewall VHub Panorama. 
  - `public_ip_name`                  - (`string`, required) The name of the Public IP address resource.
  - `create_public_ip`                - (`bool`, optional) Determines whether a new Public IP address should be created. Defaults to `true`.
  - `public_ip_resource_group_name`   - (`string`, optional, required when `create_public_ip` is `false`) The name of the resource group where the Public IP address is located when using an existing Public IP.
  - `palo_alto_virtual_appliance_key` - (`string`, optional) The key that references the Palo Alto Virtual Appliance if used.
  - `panorama_base64_config`          - (`string`, optional) The Base64 encoded configuration for connecting to the Panorama Configuration server.
  - `destination_nat`                 - (`map`, optional) Defines one or more destination NAT configurations. Each object supports the following properties:
    - `destination_nat_name`      - (`string`, required) The name of the Destination NAT. Must be unique within this map.
    - `destination_nat_protocol`  - (`string`, required) The protocol for this Destination NAT. Possible values are `TCP` or `UDP`.
    - `frontend_port`             - (`number`, required) The port on which traffic will be received. Must be in the range 1 to 65535.
    - `frontend_public_ip_key`    - (`string`, required) The key that references the Public IP address receiving the traffic.
    - `backend_port`              - (`number`, required) The port number to which traffic will be sent. Must be in the range 1 to 65535.
    - `backend_public_ip_address` - (`string`, required) The Public IP address to which traffic will be sent. Must be a valid IPv4 address.

  - `dns_settings`                 - (`map`, optional) Defines DNS settings for the cngfw. Each object supports the following properties:
    - `dns_servers`   - (`list(string)`, optional) A list of DNS servers to proxy. Cannot be used with `use_azure_dns`.
    - `use_azure_dns` - (`bool`, optional) Specifies whether Azure DNS should be used. Defaults to `false`. Cannot be used with `dns_servers`.

  If `create_public_ip` is set to `true`, a new Public IP will be created using the provided `public_ip_name`.
  If `create_public_ip` is set to `false`, the existing Public IP with `public_ip_name` will be used, and `public_ip_resource_group_name` is required.
  EOF

  type = object({
    cngfw_name                      = string
    create_public_ip                = optional(bool, true)
    public_ip_name                  = string
    public_ip_resource_group_name   = optional(string)
    panorama_base64_config          = optional(string)
    palo_alto_virtual_appliance_key = optional(string)
    destination_nat = optional(map(object({
      destination_nat_name      = string
      destination_nat_protocol  = string
      frontend_port             = number
      backend_port              = number
      backend_public_ip_address = string
    })), {})
  })

  validation { # destination_nat_name
    condition = alltrue([
      length([for _, nat in var.cngfw_config.destination_nat : nat.destination_nat_name]) == length(distinct([for _, nat in var.cngfw_config.destination_nat : nat.destination_nat_name]))
    ])
    error_message = "The `destination_nat_name` property has to be unique in a particular destination_nat."
  }
  validation { #destination_nat_protocol
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nat : [
        contains(["TCP", "UDP"], nat.destination_nat_protocol)
      ]
    ]))
    error_message = "Each destination_nat entry must have a valid protocol ('TCP' or 'UDP')."
  }
  validation { #frontend_port
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nat : [
        nat.frontend_port >= 1 && nat.frontend_port <= 65535
      ]
    ]))
    error_message = "Each destination_nat `frontend_port` property must be between 1 and 65535."
  }
  validation { #backend_port
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nat : [
        nat.backend_port >= 1 && nat.backend_port <= 65535
      ]
    ]))
    error_message = "Each destination_nat `backend_port` property must be between 1 and 65535."
  }
  validation { #backend_public_ip_address
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nat : [
        can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", nat.backend_public_ip_address))
      ]
    ]))
    error_message = "Each destination_nat `backend_public_ip_address` property must be a valid IPv4 address."
  }
}




