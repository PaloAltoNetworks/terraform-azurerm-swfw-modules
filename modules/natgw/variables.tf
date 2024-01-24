variable "name" {
  description = "Name of a NAT Gateway."
  type        = string
}

variable "resource_group_name" {
  description = "Name of a Resource Group hosting the NAT Gateway (either the existing one or the one that will be created)."
  type        = string
}

variable "location" {
  description = "Azure region. Only for newly created resources."
  type        = string
}

variable "tags" {
  description = "A map of tags that will be assigned to resources created by this module. Only for newly created resources."
  default     = {}
  type        = map(string)
}

variable "natgw" {
  description = <<-EOF
  A map defining basic NAT Gateway configuration. 

  Following properties are available:

  - `create`       - (`bool`, optional, defaults to `true`) controls if the NAT Gateway is created or sourced. When set the
                     `false` the module will only bind an existing NAT Gateway to specified subnets.
  - `zone`         - (`string`, optional, defaults to `null`) controls whether the NAT Gateway will be bound to a specific zone or
                     not. This is a string with the zone number or `null`. Used only for newly created resources.
  - `idle_timeout` - (`number`, optional, defaults to `4`) connection IDLE timeout in minutes (up to 120, by default 4). Only for
                     newly created resources.

  EOF
  default     = {}
  nullable    = false
  type = object({
    create       = optional(bool, true)
    zone         = optional(string)
    idle_timeout = optional(number, 4)
  })
  validation { # zone
    condition     = (var.natgw.zone == null || can(regex("^[1-3]$", var.natgw.zone)))
    error_message = "The `zone` variable should have value of either: \"1\", \"2\" or \"3\"."
  }
  validation { # idle_timeout
    condition     = (var.natgw.idle_timeout >= 1 && var.natgw.idle_timeout <= 120)
    error_message = "The `idle_timeout` variable should be a number between 1 and 120."
  }
}

variable "subnet_ids" {
  description = <<-EOF
  A map of subnet IDs what will be bound with this NAT Gateway.
  
  Value is the subnet ID, key value does not matter but should be unique, typically it can be a subnet name.
  EOF
  type        = map(string)
}

variable "public_ip" {
  description = <<-EOF
  A map defining a Public IP resource.

  List of available properties:

  - `create`              - (`bool`, required) controls whether a Public IP is created, sourced, or not used at all.
  - `name`                - (`string`, required) name of a created or sourced Public IP.
  - `resource_group_name` - (`string`, optional) name of a resource group hosting the sourced Public IP resource, ignored when
                            `create = true`.

  The module operates in 3 modes, depending on combination of `create` and `name` properties:

  `create` | `name` | operation
  --- | --- | ---
  `true` | `!null` | a Public IP resource is created in a resource group of the NAT Gateway
  `false` | `!null` | a Public IP resource is sourced from a resource group of the NAT Gateway, the resource group can be
                      overridden with `resource_group_name` property
  `false` | `null` | a Public IP resource will not be created or sourced at all
  
  Example:

  ```hcl
  # create a new Public IP
  public_ip = {
    create = true
    name = "new-public-ip-name"
  }

  # source an existing Public IP from an external resource group
  public_ip = {
    create              = false
    name                = "existing-public-ip-name"
    resource_group_name = "external-rg-name"
  }
  ```
  EOF
  default     = null
  type = object({
    create              = bool
    name                = string
    resource_group_name = optional(string)
  })
}

variable "public_ip_prefix" {
  description = <<-EOF
  A map defining a Public IP Prefix resource.
  
  List of available properties:

  - `create`              - (`bool`, required) controls whether a Public IP Prefix is created, sourced, or not used at all.
  - `name`                - (`string`, required) name of a created or sourced Public IP Prefix.
  - `resource_group_name` - (`string`, optional) name of a resource group hosting the sourced Public IP Prefix resource, ignored
                            when `create = true`.
  - `length`              - (`number`, optional, defaults to `28`) number of bits of the Public IP Prefix, this value can be
                            between `0` and `31` but can be limited on subscription level (Azure default is `/28`).

  The module operates in 3 modes, depending on combination of `create` and `name` properties:

  `create` | `name` | operation
  --- | --- | ---
  `true` | `!null` | a Public IP Prefix resource is created in a resource group of the NAT Gateway
  `false` | `!null` | a Public IP Prefix resource is sourced from a resource group of the NAT Gateway, the resource group can be
                      overridden with `resource_group_name` property
  `false` | `null` | a Public IP Prefix resource will not be created or sourced at all

  Example:

  ```hcl
  # create a new Public IP Prefix, default prefix length is `/28`
  public_ip_prefix = {
    create = true
    name   = "new-public-ip-prefix-name"
  }

  # source an existing Public IP Prefix from an external resource group
  public_ip = {
    create              = false
    name                = "existing-public-ip-prefix-name"
    resource_group_name = "external-rg-name"
  }
  ```
  EOF
  default     = null
  type = object({
    create              = bool
    name                = string
    resource_group_name = optional(string)
    length              = optional(number, 28)
  })
  validation {
    condition = (var.public_ip_prefix == null ||
    (try(var.public_ip_prefix.length, -1) >= 0 && try(var.public_ip_prefix.length, 32) <= 31))
    error_message = "The `length` property should be a number between 0 and 31."
  }
}
