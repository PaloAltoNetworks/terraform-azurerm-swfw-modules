variable "region" {
  description = "The name of the Azure region to deploy the resources in."
  type        = string
}

variable "tags" {
  description = "The map of tags to assign to all created resources."
  default     = {}
  type        = map(string)
}

variable "public_ip_addresses" {
  description = <<-EOF
  Map of objects describing Public IP Addresses.

  List of available properties:

  - `create`                     - (`bool`, required) controls whether a Public IP Address is created or sourced.
  - `name`                       - (`string`, required) name of a created or sourced Public IP Address.
  - `resource_group_name`        - (`string`, required) name of a Resource Group for created Public IP Address or hosting an
                                   existing Public IP Address.
  - `zones`                      - (`list`, optional, defaults to ["1", "2", "3"]) list of Availability Zones in which the Public
                                   IP Address is available, setting this variable to explicit `null` disables a zonal deployment.
  - `domain_name_label`          - (`string`, optional, defaults to `null`) a label for the Domain Name, will be used to make up
                                   the FQDN. If a domain name label is specified, an A DNS record is created for the Public IP in
                                   the Microsoft Azure DNS system.
  - `idle_timeout_in_minutes`    - (`number`, optional, defaults to Azure default) the Idle Timeout in minutes for the Public IP
                                   Address, possible values are in the range from 4 to 32.
  - `prefix_name`                - (`string`, optional) the name of an existing Public IP Prefix from where Public IP Addresses 
                                   should be allocated.
  - `prefix_resource_group_name` - (`string`, optional, defaults to the PIP's RG) name of a Resource Group hosting an existing
                                   Public IP Prefix resource.
  
  Example:

  ```hcl
  # create two new Public IP Addresses, where the first IP is only in Availability Zone 1 
  # and the second IP is in all 3 Availability Zones (default) and is allocated from a specific Public IP Prefix
  public_ip_addresses = {
    pip1 = {
      create              = true
      name                = "new-public-ip-name1"
      resource_group_name = "pip-rg-name"
      zones               = ["1"]
    }
    pip2 = {
      create                     = true
      name                       = "new-public-ip-name2"
      resource_group_name        = "pip-rg-name"
      prefix_name                = "public-ip-prefix-name"
      prefix_resource_group_name = "ippre-rg-name"
    }
  }

  # source an existing Public IP
  public_ip_addresses = {
    pip1 = {
      create              = false
      name                = "existing-public-ip-name"
      resource_group_name = "pip-rg-name"
    }
  }
  ```
  EOF
  default     = null
  type = map(object({
    create                     = bool
    name                       = string
    resource_group_name        = string
    zones                      = optional(list(string), ["1", "2", "3"])
    domain_name_label          = optional(string)
    idle_timeout_in_minutes    = optional(number)
    prefix_name                = optional(string)
    prefix_resource_group_name = optional(string)
  }))
  validation { # idle_timeout_in_minutes
    condition = alltrue([
      for _, pip in var.public_ip_addresses : (pip.idle_timeout_in_minutes >= 4 && pip.idle_timeout_in_minutes <= 32)
      if length(var.public_ip_addresses) > 0 && pip.idle_timeout_in_minutes != null
    ])
    error_message = <<-EOF
    The `idle_timeout_in_minutes` value must be a number between 4 and 32.
    EOF
  }
}

variable "public_ip_prefixes" {
  description = <<-EOF
  Map of objects describing Public IP Prefixes.
  
  List of available properties:

  - `create`              - (`bool`, required) controls whether a Public IP Prefix is created or sourced.
  - `name`                - (`string`, required) name of a created or sourced Public IP Prefix.
  - `resource_group_name` - (`string`, required) name of a Resource Group for created Public IP Prefix or hosting an existing
                            Public IP Prefix.
  - `zones`               - (`list`, optional, defaults to ["1", "2", "3"]) list of Availability Zones in which the Public IP
                            Address is available, setting this variable to explicit `null` disables a zonal deployment.
  - `length`              - (`number`, optional, defaults to `28`) number of bits of the Public IP Prefix, this value can be
                            between `0` and `31` but can be limited on subscription level (Azure default is `/28`).

  Example:

  ```hcl
  # create two new Public IP Prefixes, where the first one is only in Availability Zone 1 and with default prefix length of `/28`
  # and the second one is in all 3 Availability Zones (default) and with prefix length of `/30`
  public_ip_prefixes = {
    ippre1 = {
      create              = true
      name                = "new-public-ip-prefix-name1"
      resource_group_name = "ippre-rg-name"
      zones               = ["1"]
    }
    ippre2 = {
      create              = true
      name                = "new-public-ip-prefix-name2"
      resource_group_name = "ippre-rg-name"
      length              = 30
    }
  }

  # source an existing Public IP Prefix
  public_ip_prefixes = {
    ippre1 = {
      create              = false
      name                = "existing-public-ip-prefix-name"
      resource_group_name = "ippre-rg-name"
    }
  }
  ```
  EOF
  default     = null
  type = map(object({
    create              = bool
    name                = string
    resource_group_name = string
    zones               = optional(list(string), ["1", "2", "3"])
    length              = optional(number, 28)
  }))
  validation { # length
    condition = alltrue([
      for _, ippre in var.public_ip_prefixes : (ippre.length >= 0 && ippre.length <= 31)
      if length(var.public_ip_prefixes) > 0
    ])
    error_message = <<-EOF
    The `length` property should be a number between 0 and 31.
    EOF
  }
}