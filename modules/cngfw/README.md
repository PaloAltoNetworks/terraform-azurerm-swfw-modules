

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 4.0

### Providers

- `azurerm`, version: ~> 4.0



### Resources

- `palo_alto_next_generation_firewall_virtual_hub_panorama` (managed)
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
[`virtual_hub_id`](#virtual_hub_id) | `string` | The ID of the Azure Virtual Hub used for connecting various network resources.
[`virtual_network_id`](#virtual_network_id) | `string` | The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw.
[`trusted_subnet_id`](#trusted_subnet_id) | `string` | The ID of the subnet designated for trusted resources within the virtual network.
[`untrusted_subnet_id`](#untrusted_subnet_id) | `string` | The ID of the subnet designated for untrusted resources within the virtual network.
[`palo_alto_virtual_appliance`](#palo_alto_virtual_appliance) | `map` | Map of objects describing Palo Alto Virtual Appliance instances.

### Outputs

Name |  Description
--- | ---
`palo_alto_virtual_network_appliance_ids` | The identifiers of the created Palo Alto Virtual Network Appliances.
`cngfw_public_ip_address` | Public IP Addresses of the CNGFW

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


Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### cngfw_config

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


Type: 

```hcl
object({
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
    })))
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_hub_id

The ID of the Azure Virtual Hub used for connecting various network resources.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### virtual_network_id

The ID of the Azure Virtual Network (VNet) to be used for connecting to cngfw.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### trusted_subnet_id

The ID of the subnet designated for trusted resources within the virtual network.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### untrusted_subnet_id

The ID of the subnet designated for untrusted resources within the virtual network.

Type: string

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
