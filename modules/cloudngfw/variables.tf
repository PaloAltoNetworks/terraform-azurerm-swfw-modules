variable "name" {
  description = "The name of the Palo Alto Next Generation Firewall instance."
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

variable "virtual_hub_id" {
  description = <<-EOF
  The ID of the Azure Virtual Hub used for connecting various network resources.
  This variable is required when `attachment_type` is set to "vwan".
  EOF
  default     = null
  type        = string
}

variable "virtual_network_id" {
  description = <<-EOF
  The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw.
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

variable "untrusted_subnet_id" {
  description = <<-EOF
  The ID of the subnet designated for untrusted resources within the virtual network.
  This variable is required when `attachment_type` is set to "vnet".
  EOF
  default     = null
  type        = string
}

variable "public_ip_ids" {
  description = <<-EOF
  A map of IDs for public IP addresses. Each key represents a logical identifier, and the value is the resource ID of a public IP. 
  This variable can be populated manually with existing public IP IDs or dynamically through outputs from other modules, 
  such as the `public_ip` module.
  EOF
  default     = null
  type        = map(string)
}

variable "egress_nat_ip_ids" {
  description = <<-EOF
  A map of IDs for egress NAT public IP addresses. Each key represents a logical identifier, and the value is the resource ID of a public IP. 
  These IPs are used for outbound traffic from the firewall to the internet. 

  This variable can be manually populated with existing public IP IDs or dynamically derived from other modules, 
  such as the `public_ip` module, to ensure proper outbound connectivity.
  EOF
  default     = null
  type        = map(string)
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

variable "plan_id" {
  description = <<-EOF
  The former plan_id panw-cloud-ngfw-payg is defined as stop sell, but has been set as the default to not break any existing 
  resources that were originally provisioned with it. Users need to explicitly set plan_id to panw-cngfw-payg when creating new resources.
  EOF
  type        = string
  default     = "panw-cngfw-payg"
}

variable "marketplace_offer_id" {
  description = <<-EOF
  The marketplace offer ID. Defaults to pan_swfw_cloud_ngfw. Changing this forces a new resource to be created.
  EOF
  type        = string
  default     = "pan_swfw_cloud_ngfw"
}

variable "management_mode" {
  description = <<-EOF
  Defines how the cngfw is managed.
  - When set to `panorama`, the cngfw policies are managed through Panorama.
  - When set to `rulestack`, the cngfw policies are managed through Azure Rulestack.
  EOF
  type        = string
  validation {
    condition     = var.management_mode == "panorama" || var.management_mode == "rulestack"
    error_message = "The management_mode must be set to 'panorama' or 'rulestack'."
  }
}

variable "palo_alto_virtual_appliance_name" {
  description = <<-EOF
  The name of the Palo Alto Virtual Appliance. 

  This variable is required when `attachment_type` is set to "vwan" and defines the name of the appliance 
  to be deployed in the virtual WAN environment. Changing this value will force the creation of a new 
  Palo Alto Local Network Virtual Appliance.
  EOF
  default     = null
  type        = string
}

variable "cngfw_config" {
  description = <<-EOF
  Map of objects describing Palo Alto Next Generation Firewalls (cngfw).

  List of available properties:

  - `create_public_ip`                - (`bool`, optional, defaults to `true`) controls if the Public IP resource is created or 
                                        sourced. This field is ignored when the variable `public_ip_ids` is used.
  - `public_ip_name`                  - (`string`, optional) the name of the Public IP resource. This field is required unless 
                                        the variable `public_ip_ids` is used.
  - `public_ip_resource_group_name`   - (`string`, optional) the name of the Resource Group hosting the Public IP resource. 
                                        This is used only for sourced resources.
  - `rulestack_id`                    - (`string`, optional) the ID of the Local Rulestack used to configure this Firewall 
                                        Resource. This field is required when `management_mode` is set to `rulestack`.
  - `panorama_base64_config`          - (`string`, optional) the Base64-encoded configuration for connecting to the Panorama server. 
                                        This field is required when `management_mode` is set to "panorama".
  - `palo_alto_virtual_appliance_key` - (`string`, optional) the key referencing a Palo Alto Virtual Appliance, if applicable. 
                                        This field is required when `attachment_type` is set to `vwan`.
  - `destination_nats`                 - (`map`, optional) defines one or more destination NAT configurations. 
                                        Each object supports the following properties:
    - `destination_nat_name`              - (`string`, required) the name of the Destination NAT. Must be unique within this map.
    - `destination_nat_protocol`          - (`string`, required) the protocol for this Destination NAT. Possible values are `TCP` or `UDP`.
    - `frontend_port`                     - (`number`, required) the port on which traffic will be received. Must be in the range 1 to 65535.
    - `frontend_public_ip_address_id`     - (`string`, optional) the id referencing the public IP that receives the traffic. 
                                            This is used only when the variable `public_ip_ids` is utilized.
    - `backend_port`                      - (`number`, required) the port number to which traffic will be sent. 
                                             Must be in the range 1 to 65535.
    - `backend_ip_address`                - (`string`, required) the IPv4 address to which traffic will be forwarded.
  EOF
  type = object({
    create_public_ip              = optional(bool, true)
    public_ip_name                = optional(string)
    public_ip_resource_group_name = optional(string)
    rulestack_id                  = optional(string)
    panorama_base64_config        = optional(string)
    destination_nats = optional(map(object({
      destination_nat_name          = string
      destination_nat_protocol      = string
      frontend_public_ip_address_id = optional(string)
      frontend_port                 = number
      backend_port                  = number
      backend_ip_address            = string
    })), {})
  })
  validation { # destination_nat_name
    condition = alltrue([
      length([for _, nat in var.cngfw_config.destination_nats : nat.destination_nat_name])
      == length(distinct([for _, nat in var.cngfw_config.destination_nats : nat.destination_nat_name]))
    ])
    error_message = "The `destination_nat_name` property value has to be unique in a particular destination_nat."
  }
  validation { #destination_nat_protocol
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nats : [
        contains(["TCP", "UDP"], nat.destination_nat_protocol)
      ]
    ]))
    error_message = "Each destination_nat entry must have a valid protocol ('TCP' or 'UDP')."
  }
  validation { #frontend_port
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nats : [
        nat.frontend_port >= 1 && nat.frontend_port <= 65535
      ]
    ]))
    error_message = "Each destination_nat `frontend_port` property value must be between 1 and 65535."
  }
  validation { #backend_port
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nats : [
        nat.backend_port >= 1 && nat.backend_port <= 65535
      ]
    ]))
    error_message = "Each destination_nat `backend_port` property value must be between 1 and 65535."
  }
  validation { #backend_ip_address
    condition = alltrue(flatten([
      for _, nat in var.cngfw_config.destination_nats : [
        can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", nat.backend_ip_address))
      ]
    ]))
    error_message = "Each destination_nat `backend_ip_address` property value must be a valid IPv4 address."
  }
}




