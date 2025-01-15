variable "name" {
  description = "The name of the Route Server."
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
  An ID of a Subnet in which the Route Server will be created.

  This has to be a dedicated Subnet named `RouteServerSubnet`.
  EOF
  type        = string
}

variable "zones" {
  description = <<-EOF
  After provider version 3.x you need to specify in which availability zone(s) you want to place a Public IP address.

  For zone-redundant with 3 availability zones in current region, value will be:
  ```["1","2","3"]```
  EOF
  default     = ["1", "2", "3"]
  type        = list(string)
}

variable "public_ip" {
  description = <<-EOF
  A map defining a Public IP resource.

  List of available properties:

  - `create`              - (`bool`, required) controls whether a Public IP is created or sourced.
  - `name`                - (`string`, optional) name of a created or sourced Public IP, required unless `id` property is used.
  - `resource_group_name` - (`string`, optional) name of a resource group hosting the sourced Public IP resource, ignored when
                            `create = true`.
  - `id`                  - (`string`, optional, defaults to `null`) ID of the Public IP to associate with the Route Server. 
                            Property is used when Public IP Address is not created or sourced within this module.
  
  Example:

  ```hcl
  # create a new Public IP
  public_ip = {
    create = true
    name   = "new-public-ip-name"
  }

  # source an existing Public IP from an external resource group
  public_ip = {
    create              = false
    name                = "existing-public-ip-name"
    resource_group_name = "external-rg-name"
  }
  ```
  EOF
  type = object({
    create              = bool
    name                = optional(string)
    resource_group_name = optional(string)
    id                  = optional(string)
  })
  validation { # id, name
    condition     = var.public_ip != null ? (var.public_ip.name != null || var.public_ip.id != null) : true
    error_message = <<-EOF
    Either `name` or `id` property must be set.
    EOF
  }
  validation { # id, create, name
    condition = var.public_ip != null ? (
      var.public_ip.id != null ? var.public_ip.create == false && var.public_ip.name == null : true
    ) : true
    error_message = <<-EOF
    When using `id` property, `create` must be set to `false` and `name` must not be set.
    EOF
  }
}

variable "sku" {
  description = "Sets the SKU of the Route Server. Only possible value at the moment is `Standard`."
  default     = "Standard"
  type        = string
  validation {
    condition     = contains(["Standard"], var.sku)
    error_message = <<-EOF
    The `sku` property can take one of the following values: "Standard".
    EOF
  }
}

variable "branch_to_branch_traffic" {
  description = "Controls whether to enable route exchange between Azure Route Server and the gateways."
  default     = true
  type        = bool
}

variable "bgp_connections" {
  description = <<-EOF
  A map containing Route Server BGP connections details.

  List of available properties:
  - `name`     - (`string`, required) the name of the BGP connection.
  - `peer_asn` - (`string`, required) the peer autonomous system number for the BGP connection.
  - `peer_ip`  - (`string`, required) the peer IP address for the BGP connection.
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    name     = string
    peer_asn = string
    peer_ip  = string
  }))
}
