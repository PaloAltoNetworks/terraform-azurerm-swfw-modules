variable "virtual_wan_name" {
  description = "The name of the Azure Virtual WAN."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Virtual WAN should exist."
  type        = string
}

variable "create_virtual_wan" {
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

