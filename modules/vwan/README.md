# Palo Alto Networks vWAN Module for Azure

A Terraform module for deploying a Virtual WAN (vWAN) required for the firewalls in Azure.

## Usage

TBD

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 4.0

### Providers

- `azurerm`, version: ~> 4.0



### Resources

- `virtual_wan` (managed)
- `virtual_wan` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`virtual_wan_name`](#virtual_wan_name) | `string` | The name of the Azure Virtual WAN.
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group where the Virtual WAN should exist.
[`region`](#region) | `string` | The name of the Azure region to deploy the virtual WAN.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_virtual_wan`](#create_virtual_wan) | `bool` | Controls Virtual WAN creation.
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`allow_branch_to_branch_traffic`](#allow_branch_to_branch_traffic) | `bool` | Optional boolean flag to specify whether branch-to-branch traffic is allowed.
[`disable_vpn_encryption`](#disable_vpn_encryption) | `bool` | Optional boolean flag to specify whether VPN encryption is disabled.

### Outputs

Name |  Description
--- | ---
`virtual_wan_id` | The identifier of the created or sourced Virtual WAN.

### Required Inputs details

#### virtual_wan_name

The name of the Azure Virtual WAN.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### resource_group_name

The name of the Resource Group where the Virtual WAN should exist.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### region

The name of the Azure region to deploy the virtual WAN

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### create_virtual_wan

Controls Virtual WAN creation. When set to `true`, creates the Virtual WAN, otherwise just uses a pre-existing Virtual WAN.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### allow_branch_to_branch_traffic

Optional boolean flag to specify whether branch-to-branch traffic is allowed. Defaults to true.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### disable_vpn_encryption

Optional boolean flag to specify whether VPN encryption is disabled. Defaults to false.

Type: bool

Default value: `false`

<sup>[back to list](#modules-optional-inputs)</sup>
