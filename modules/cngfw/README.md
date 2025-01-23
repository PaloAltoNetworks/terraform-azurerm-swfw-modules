# Palo Alto Networks CNGFW Module for Azure

A Terraform module for deploying Palo Alto Networks Cloud Next-Generation Firewalls (CNGFW) in Azure. This module supports flexible configurations, allowing the creation of CNGFW resources based on different attachment types and management modes. Additionally, the module provides options to create public IP addresses or use existing ones.

## Usage

This module is designed to work in several *modes* depending on which variables or flags are set. Most common usage scenarios are:

- management_mode = "panorama" & attachment_type ="vnet" - deploys CNGFW attached to a Virtual Hub in a Virtual WAN environment,
managed via Panorama (using panorama_base64_config). Supports creation or referencing of public IP addresses for connectivity.

```hcl
cngfws = {
  "cngfw" = {
    attachment_type      = "vnet"
    management_mode      = "panorama"
    virtual_network_key  = "cngfw-vnet"
    trusted_subnet_key   = "trusted"
    untrusted_subnet_key = "untrusted"
    cngfw_config = {
      cngfw_name                 = "cngfw"
      public_ip_keys             = ["cngfw_public_ip"]
      egress_nat_ip_address_keys = ["cngfw_public_ip"]
      panorama_base64_config     = "" # TODO: Put panorama connection string
    }
  }
}
```
- management_mode = "panorama" & attachment_type ="vhub" - deploys CNGFW attached to a Virtual Hub in a Virtual WAN environment,
managed via Panorama (using panorama_base64_config). Supports creation or referencing of public IP addresses for connectivity.

```hcl
cngfws = {
  "cngfw" = {
    attachment_type      = "vhub"
    management_mode      = "panorama"
    virtual_wan_key = "virtual_wan"
    virtual_hub_key = "virtual_hub"
    palo_alto_virtual_appliance = {
      "cngfw-vhub-nva" = {
        palo_alto_virtual_appliance_name = "cngfw-vhub-nva"
      }
    }
    cngfw_config = {
      cngfw_name                 = "cngfw"
      public_ip_keys             = ["cngfw_public_ip"]
      egress_nat_ip_address_keys = ["cngfw_public_ip"]
      panorama_base64_config     = "" # TODO: Put panorama connection string
    }
  }
}
```

- management_mode = "rulestack" & attachment_type ="vnet" - deploys CNGFW attached to a Virtual Network (VNet) with a local
rulestack for policy management. Requires VNet-related parameters such as trusted and untrusted subnets, along with the rulestack ID.

```hcl
cngfws = {
  "cngfw" = {
    attachment_type      = "vnet"
    management_mode      = "rulestack"
    virtual_network_key  = "cngfw-vnet"
    trusted_subnet_key   = "trusted"
    untrusted_subnet_key = "untrusted"
    cngfw_config = {
      cngfw_name                 = "cngfw"
      public_ip_keys             = ["cngfw_public_ip"]
      egress_nat_ip_address_keys = ["cngfw_public_ip"]
      rulestack_id               = "" # TODO: Put rulestack ID
    }
  }
}
```

- management_mode = "rulestack" & attachment_type ="vhub" - deploys CNGFW attached to a Virtual Hub in a Virtual WAN environment,
managed through a local rulestack. Includes options to create or reference public IP addresses.

```hcl
cngfws = {
  "cngfw" = {
    attachment_type      = "vhub"
    management_mode      = "panorama"
    virtual_wan_key = "virtual_wan"
    virtual_hub_key = "virtual_hub"
    palo_alto_virtual_appliance = {
      "cngfw-vhub-nva" = {
        palo_alto_virtual_appliance_name = "cngfw-vhub-nva"
      }
    }
    cngfw_config = {
      cngfw_name                 = "cngfw"
      public_ip_keys             = ["cngfw_public_ip"]
      egress_nat_ip_address_keys = ["cngfw_public_ip"]
      rulestack_id               = "" # TODO: Put rulestack ID
    }
  }
}
```

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 4.0

### Providers

- `azurerm`, version: ~> 4.0



### Resources

- `palo_alto_next_generation_firewall_virtual_hub_local_rulestack` (managed)
- `palo_alto_next_generation_firewall_virtual_hub_panorama` (managed)
- `palo_alto_next_generation_firewall_virtual_network_local_rulestack` (managed)
- `palo_alto_next_generation_firewall_virtual_network_panorama` (managed)
- `palo_alto_virtual_network_appliance` (managed)
- `public_ip` (managed)
- `public_ip` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group to use.
[`region`](#region) | `string` | The name of the Azure region to deploy the resources in.
[`attachment_type`](#attachment_type) | `string` | Defines how the cngfw (Cloud NGFW) is attached.
[`management_mode`](#management_mode) | `string` | Defines how the cngfw is managed.
[`cngfw_config`](#cngfw_config) | `object` | Map of objects describing Palo Alto Next Generation Firewalls (cngfw).

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`name_prefix`](#name_prefix) | `string` | A prefix that will be added to all created resources.
[`virtual_hub_id`](#virtual_hub_id) | `string` | The ID of the Azure Virtual Hub used for connecting various network resources.
[`virtual_network_id`](#virtual_network_id) | `string` | The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw.
[`trusted_subnet_id`](#trusted_subnet_id) | `string` | The ID of the subnet designated for trusted resources within the virtual network.
[`untrusted_subnet_id`](#untrusted_subnet_id) | `string` | The ID of the subnet designated for untrusted resources within the virtual network.
[`public_ip_ids`](#public_ip_ids) | `map` | A map of IDs for public IP addresses.
[`palo_alto_virtual_appliance`](#palo_alto_virtual_appliance) | `map` | Map of objects describing Palo Alto Virtual Appliance instances.

### Outputs

Name |  Description
--- | ---
`palo_alto_virtual_network_appliance_ids` | The identifiers of the created Palo Alto Virtual Network Appliances.

### Required Inputs details

#### resource_group_name

The name of the Resource Group to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### region

The name of the Azure region to deploy the resources in.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### attachment_type

Defines how the cngfw (Cloud NGFW) is attached.
- When set to `vnet`, the cngfw is used to filter traffic between trusted and untrusted subnets within a Virtual Network (VNet).
- When set to `vwan`, the cngfw is used to filter traffic within the Azure Virtual Wan.


Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### management_mode

Defines how the cngfw is managed.
- When set to `panorama`, the cngfw policies are managed through Panorama.
- When set to `rulestack`, the cngfw policies are managed through Azure Rulestack.


Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### cngfw_config

Map of objects describing Palo Alto Next Generation Firewalls (cngfw).

List of available properties:

- `cngfw_name`                      - (`string`, required) The name of the Palo Alto Next Generation Firewall instance.
- `create_public_ip`                - (`bool`, optional, defaults to `true`) Controls if the Public IP resource is created or 
                                      sourced. This field is ignored when the variable `public_ip_ids` is used.
- `public_ip_name`                  - (`string`, optional) The name of the Public IP resource. This field is required unless 
                                      the variable `public_ip_ids` is used.
- `public_ip_resource_group_name`   - (`string`, optional) The name of the Resource Group hosting the Public IP resource. 
                                      This is used only for sourced resources.
- `public_ip_keys`                  - (`list(string)`, optional) A list of keys referencing the public IPs whose IDs are 
                                      provided in the variable `public_ip_ids`. This is used only when the variable 
                                      `public_ip_ids` is utilized.
- `egress_nat_ip_address_keys`      - (`list(string)`, optional) A list of keys referencing public IPs used for egress NAT 
                                      traffic. This is used only when the variable `public_ip_ids` is utilized.
- `rulestack_id`                    - (`string`, optional) The ID of the Local Rulestack used to configure this Firewall 
                                      Resource. This field is required when `management_mode` is set to "rulestack".
- `panorama_base64_config`          - (`string`, optional) The Base64-encoded configuration for connecting to the Panorama server. 
                                      This field is required when `management_mode` is set to "panorama".
- `palo_alto_virtual_appliance_key` - (`string`, optional) The key referencing a Palo Alto Virtual Appliance, if applicable. 
                                      This field is required when `attachment_type` is set to "vwan".
- `destination_nat`                 - (`map`, optional) Defines one or more destination NAT configurations. 
                                      Each object supports the following properties:
  - `destination_nat_name`      - (`string`, required) The name of the Destination NAT. Must be unique within this map.
  - `destination_nat_protocol`  - (`string`, required) The protocol for this Destination NAT. Possible values are `TCP` or `UDP`.
  - `frontend_port`             - (`number`, required) The port on which traffic will be received. Must be in the range 1 to 65535.
  - `frontend_public_ip_key`    - (`string`, optional) The key referencing the public IP that receives the traffic. 
                                  This is used only when the variable `public_ip_ids` is utilized.
  - `backend_port`              - (`number`, required) The port number to which traffic will be sent. 
                                  Must be in the range 1 to 65535.
  - `backend_ip_address`        - (`string`, required) The IPv4 address to which traffic will be forwarded.


Type: 

```hcl
object({
    cngfw_name                      = string
    create_public_ip                = optional(bool, true)
    public_ip_name                  = optional(string)
    public_ip_resource_group_name   = optional(string)
    public_ip_keys                  = optional(list(string))
    egress_nat_ip_address_keys      = optional(list(string))
    rulestack_id                    = optional(string)
    panorama_base64_config          = optional(string)
    palo_alto_virtual_appliance_key = optional(string)
    destination_nat = optional(map(object({
      destination_nat_name     = string
      destination_nat_protocol = string
      frontend_public_ip_key   = optional(string)
      frontend_port            = number
      backend_port             = number
      backend_ip_address       = string
    })), {})
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### name_prefix

A prefix that will be added to all created resources.
There is no default delimiter applied between the prefix and the resource name.
Please include the delimiter in the actual prefix.


Type: string

Default value: ``

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_hub_id

The ID of the Azure Virtual Hub used for connecting various network resources.
This variable is required when `attachment_type` is set to "vwan".


Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_network_id

The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw.
This variable is required when `attachment_type` is set to "vnet".


Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### trusted_subnet_id

The ID of the subnet designated for trusted resources within the virtual network.
This variable is required when `attachment_type` is set to "vnet".


Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### untrusted_subnet_id

The ID of the subnet designated for untrusted resources within the virtual network.
This variable is required when `attachment_type` is set to "vnet".


Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### public_ip_ids

A map of IDs for public IP addresses. Each key represents a logical identifier, and the value is the resource ID of a public IP. 

This variable can be populated manually with existing public IP IDs or dynamically through outputs from other modules, 
such as the `public_ip` module.


Type: map(string)

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### palo_alto_virtual_appliance

Map of objects describing Palo Alto Virtual Appliance instances.

Each object in the map has the following properties:

- `palo_alto_virtual_appliance_name` - (`string`, required) The name of the Palo Alto Virtual Appliance instance.
  


Type: 

```hcl
map(object({
    palo_alto_virtual_appliance_name = string
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
