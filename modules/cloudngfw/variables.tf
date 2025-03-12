variable "name" {
  description = "The name of the Azure Cloud Next-Generation Firewall by Palo Alto Networks."
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

variable "attachment_type" {
  description = <<-EOF
  Defines how the cloudngfw (Cloud NGFW) is attached.
  - When set to `vnet`, the cloudngfw is used to filter traffic between trusted and untrusted subnets within a Virtual Network.
  - When set to `vwan`, the cloudngfw is used to filter traffic within the Azure Virtual WAN.
  EOF
  type        = string
  validation {
    condition     = contains(["vnet", "vwan"], var.attachment_type)
    error_message = <<-EOF
    The `attachment_type` must be either \"vnet\" or \"vwan\".
    EOF
  }
}

variable "virtual_network_id" {
  description = <<-EOF
  The ID of the Azure Virtual Network (VNET) to be used for connecting to cloudngfw.
  This variable is required when `attachment_type` is set to "vnet".
  EOF
  default     = null
  type        = string
}

variable "untrusted_subnet_id" {
  description = <<-EOF
  The ID of the subnet designated for untrusted resources within the virtual network.
  This variable is required when `attachment_type` is set to "vnet".
  EOF
  default     = null
  type        = string
}

variable "trusted_subnet_id" {
  description = <<-EOF
  The ID of the subnet designated for trusted resources within the virtual network.
  This variable is required when `attachment_type` is set to "vnet".
  EOF
  default     = null
  type        = string
}

variable "virtual_hub_id" {
  description = <<-EOF
  The ID of the Azure Virtual Hub used for connecting various network resources.
  This variable is required when `attachment_type` is set to "vwan".
  EOF
  default     = null
  type        = string
}

variable "management_mode" {
  description = <<-EOF
  Defines how the cloudngfw is managed.
  - When set to `panorama`, the cloudngfw policies are managed through Panorama.
  - When set to `rulestack`, the cloudngfw policies are managed through Azure Rulestack.
  EOF
  type        = string
  validation {
    condition     = contains(["panorama", "rulestack"], var.management_mode)
    error_message = <<-EOF
    The `management_mode` must be set to \"panorama\" or \"rulestack\".
    EOF
  }
}

variable "cloudngfw_config" {
  description = <<-EOF
  Map of objects describing Palo Alto Next Generation Firewalls (cloudngfw).

  List of available properties:

  - `plan_id`                         - (`string`, optional, defaults to `panw-cngfw-payg`) the former plan_id
                                        `panw-cloud-ngfw-payg` is defined as stop sell, but has been set as the provider default
                                        to not break any existing resources that were originally provisioned with it. Users need
                                        to explicitly set the `plan_id` to `panw-cngfw-payg` when creating new resources.
  - `marketplace_offer_id`            - (`string`, optional, defaults to `pan_swfw_cloud_ngfw`) the marketplace offer ID,
                                        changing this forces a new resource to be created.
  - `panorama_base64_config`          - (`string`, optional) the Base64-encoded configuration for connecting to Panorama server. 
                                        This field is required when `management_mode` is set to `panorama`.
  - `rulestack_id`                    - (`string`, optional) the ID of the Local Rulestack used to configure this Firewall 
                                        Resource. This field is required when `management_mode` is set to `rulestack`.
  - `create_public_ip`                - (`bool`, optional, defaults to `true`) controls if the Public IP resource is created or 
                                        sourced. This field is ignored when the variable `public_ip_ids` is used.
  - `public_ip_name`                  - (`string`, optional) the name of the Public IP resource. This field is required unless 
                                        the variable `public_ip_ids` is used.
  - `public_ip_resource_group_name`   - (`string`, optional) the name of the Resource Group hosting the Public IP resource. 
                                        This is used only for sourced resources.
  - `public_ip_ids`                   - (`map`, optional) a map of IDs for public IP addresses. Each key represents a logical
                                        identifier and the value is the resource ID of the public IP. 
  - `egress_nat_ip_ids`               - (`map`, optional) a map of IDs for egress NAT public IP addresses. Each key represents
                                        a logical identifier and the value is the resource ID of the public IP.
  - `trusted_address_ranges`          - (`list`, optional) a list of public IP address ranges that will be treated as internal
                                        traffic by Cloud NGFW in addition to RFC 1918 private subnets. Each list entry has to be
                                        in a CIDR format.
  - `destination_nats`                - (`map`, optional) defines one or more destination NAT configurations.
                                        Each object supports the following properties:
    - `destination_nat_name`          - (`string`, required) the name of the Destination NAT. Must be unique within this map.
    - `destination_nat_protocol`      - (`string`, required) the protocol for this Destination NAT. Possible values are `TCP` or
                                        `UDP`.
    - `frontend_public_ip_address_id` - (`string`, optional) the ID referencing the public IP that receives the traffic. 
                                        This is used only when the variable `public_ip_ids` is utilized.
    - `frontend_port`                 - (`number`, required) the port on which traffic will be received. Must be in the range
                                        from 1 to 65535.
    - `backend_ip_address`            - (`string`, required) the IPv4 address to which traffic will be forwarded.
    - `backend_port`                  - (`number`, required) the port number to which traffic will be sent. Must be in the range
                                        from 1 to 65535.
  EOF
  type = object({
    plan_id                       = optional(string, "panw-cngfw-payg")
    marketplace_offer_id          = optional(string, "pan_swfw_cloud_ngfw")
    panorama_base64_config        = optional(string)
    rulestack_id                  = optional(string)
    create_public_ip              = optional(bool, true)
    public_ip_name                = optional(string)
    public_ip_resource_group_name = optional(string)
    public_ip_ids                 = optional(map(string))
    egress_nat_ip_ids             = optional(map(string))
    trusted_address_ranges        = optional(list(string))
    destination_nats = optional(map(object({
      destination_nat_name          = string
      destination_nat_protocol      = string
      frontend_public_ip_address_id = optional(string)
      frontend_port                 = number
      backend_ip_address            = string
      backend_port                  = number
    })), {})
  })
  validation { # trusted_address_ranges
    condition = alltrue([
      for v in coalesce(var.cloudngfw_config.trusted_address_ranges, []) :
      can(regex("^(\\d{1,3}\\.){3}\\d{1,3}\\/[1-3]?[0-9]$", v))
    ])
    error_message = <<-EOF
    All items in `trusted_address_ranges` should be in CIDR notation.
    EOF
  }
  validation { # destination_nat_name
    condition = alltrue([
      length([for _, nat in var.cloudngfw_config.destination_nats : nat.destination_nat_name])
      == length(distinct([for _, nat in var.cloudngfw_config.destination_nats : nat.destination_nat_name]))
    ])
    error_message = <<-EOF
    The `destination_nat_name` property value has to be unique in a particular destination_nat.
    EOF
  }
  validation { # destination_nat_protocol
    condition = alltrue(flatten([
      for _, nat in var.cloudngfw_config.destination_nats : [
        contains(["TCP", "UDP"], nat.destination_nat_protocol)
      ]
    ]))
    error_message = <<-EOF
    Each `destination_nat` entry must have a valid protocol of /"TCP"/ or /"UDP"/.
    EOF
  }
  validation { # frontend_port
    condition = alltrue(flatten([
      for _, nat in var.cloudngfw_config.destination_nats : [
        nat.frontend_port >= 1 && nat.frontend_port <= 65535
      ]
    ]))
    error_message = <<-EOF
    Each destination_nat `frontend_port` property value must be between 1 and 65535.
    EOF
  }
  validation { # backend_ip_address
    condition = alltrue(flatten([
      for _, nat in var.cloudngfw_config.destination_nats : [
        can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", nat.backend_ip_address))
      ]
    ]))
    error_message = <<-EOF
    Each destination_nat `backend_ip_address` property value must be a valid IPv4 address.
    EOF
  }
  validation { # backend_port
    condition = alltrue(flatten([
      for _, nat in var.cloudngfw_config.destination_nats : [
        nat.backend_port >= 1 && nat.backend_port <= 65535
      ]
    ]))
    error_message = <<-EOF
    Each destination_nat `backend_port` property value must be between 1 and 65535.
    EOF
  }
}
