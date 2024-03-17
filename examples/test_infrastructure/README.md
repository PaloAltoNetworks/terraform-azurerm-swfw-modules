<!-- BEGIN_TF_DOCS -->
# Test Infrastructure code

Terraform code to deploy a test infrastructure consisting of:

* two VNETs that can be peered with the transit VNET deployed in any of the examples, each contains:
  * a Linux-based VM running NGINX server to mock a web application
  * an Azure Bastion (enables SSH access to the VM)
  * UDRs forcing the traffic to flow through the NVA deployed by any of NGFW examples.

## Usage

To use this code, please deploy one of the examples first. Then copy the [`examples.tfvars`](./example.tfvars) to `terraform.tfvars` and edit it to your needs.

Please correct the values marked with `TODO` markers at minimum.

## Reference

## Module's Required Inputs

Name | Type | Description
--- | --- | ---
[`region`](#region) | `string` | The Azure region to use.
[`resource_group_name`](#resource_group_name) | `string` | Name of the Resource Group.
[`vnets`](#vnets) | `map` | A map defining VNETs.


## Module's Optional Inputs

Name | Type | Description
--- | --- | ---
[`tags`](#tags) | `map` | Map of tags to assign to the created resources.
[`name_prefix`](#name_prefix) | `string` | A prefix that will be added to all created resources.
[`create_resource_group`](#create_resource_group) | `bool` | When set to `true` it will cause a Resource Group creation.
[`hub_resource_group_name`](#hub_resource_group_name) | `string` | Name of the Resource Group hosting the hub/transit infrastructure.
[`hub_vnet_name`](#hub_vnet_name) | `string` | Name of the hub/transit VNET.
[`vm_size`](#vm_size) | `string` | Azure test VM size.
[`username`](#username) | `string` | Name of the VM admin account.
[`password`](#password) | `string` | A password for the admin account.
[`test_vms`](#test_vms) | `map` | A map defining test VMs.
[`bastions`](#bastions) | `map` | A map containing Azure Bastion definitions.



## Module's Outputs

Name |  Description
--- | ---
`username` | Test VMs admin account.
`password` | Password for the admin user.
`vm_private_ips` | A map of private IPs assigned to test VMs.

## Module's Nameplate


Requirements needed by this module:

- `terraform`, version: >= 1.5, < 2.0


Providers used in this module:

- `random`
- `azurerm`


Modules used in this module:
Name | Version | Source | Description
--- | --- | --- | ---
`vnet` | - | ../../modules/vnet | Manage the network required for the topology.
`vnet_peering` | - | ../../modules/vnet_peering | 


Resources used in this module:

- `bastion_host` (managed)
- `linux_virtual_machine` (managed)
- `network_interface` (managed)
- `public_ip` (managed)
- `resource_group` (managed)
- `password` (managed)
- `resource_group` (data)

## Inputs/Outpus details

### Required Inputs



#### region

The Azure region to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>



#### resource_group_name

Name of the Resource Group.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### vnets

A map defining VNETs.
  
For detailed documentation on each property refer to [module documentation](../../modules/vnet/README.md)

- `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, 
                              `false` will source an existing VNET.
- `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = false` this should be
                              a full resource name, including prefixes.
- `address_space`           - (`list(string)`, required when `create_virtual_network = false`) a list of CIDRs for a newly
                              created VNET
- `resource_group_name`     - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which
                              the VNET will reside or is sourced from
- `create_subnets`          - (`bool`, optional, defaults to `true`) if `true`, create Subnets inside the Virtual Network,
                              otherwise use source existing subnets
- `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                              [VNET module documentation](../../modules/vnet/README.md#subnets)
- `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                              [VNET module documentation](../../modules/vnet/README.md#network_security_groups)
- `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                              [VNET module documentation](../../modules/vnet/README.md#route_tables)


Type: 

```hcl
map(object({
    name                    = string
    resource_group_name     = optional(string)
    create_virtual_network  = optional(bool, true)
    address_space           = optional(list(string))
    hub_resource_group_name = optional(string)
    hub_vnet_name           = optional(string)
    network_security_groups = optional(map(object({
      name                          = string
      disable_bgp_route_propagation = optional(bool)
      rules = optional(map(object({
        name                         = string
        priority                     = number
        direction                    = string
        access                       = string
        protocol                     = string
        source_port_range            = optional(string)
        source_port_ranges           = optional(list(string))
        destination_port_range       = optional(string)
        destination_port_ranges      = optional(list(string))
        source_address_prefix        = optional(string)
        source_address_prefixes      = optional(list(string))
        destination_address_prefix   = optional(string)
        destination_address_prefixes = optional(list(string))
      })), {})
    })), {})
    route_tables = optional(map(object({
      name = string
      routes = map(object({
        name                = string
        address_prefix      = string
        next_hop_type       = string
        next_hop_ip_address = optional(string)
      }))
    })), {})
    create_subnets = optional(bool, true)
    subnets = optional(map(object({
      name                            = string
      address_prefixes                = optional(list(string), [])
      network_security_group_key      = optional(string)
      route_table_key                 = optional(string)
      enable_storage_service_endpoint = optional(bool, false)
    })), {})
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>










### Optional Inputs


#### tags

Map of tags to assign to the created resources.

Type: map(string)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>


#### name_prefix

A prefix that will be added to all created resources.
There is no default delimiter applied between the prefix and the resource name. Please include the delimiter in the actual prefix.

Example:
```
name_prefix = "test-"
```
  
NOTICE. This prefix is not applied to existing resources.
If you plan to reuse i.e. a VNET please specify it's full name, even if it is also prefixed with the same value as the one in this property.


Type: string

Default value: ``

<sup>[back to list](#modules-optional-inputs)</sup>

#### create_resource_group

When set to `true` it will cause a Resource Group creation. Name of the newly specified RG is controlled by `resource_group_name`.
When set to `false` the `resource_group_name` parameter is used to specify a name of an existing Resource Group.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>



#### hub_resource_group_name

Name of the Resource Group hosting the hub/transit infrastructure. This value is required to create peering between the spoke and the hub VNET.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### hub_vnet_name

Name of the hub/transit VNET. This value is required to create peering between the spoke and the hub VNET.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vm_size

Azure test VM size.

Type: string

Default value: `Standard_D1_v2`

<sup>[back to list](#modules-optional-inputs)</sup>

#### username

Name of the VM admin account.

Type: string

Default value: `panadmin`

<sup>[back to list](#modules-optional-inputs)</sup>

#### password

A password for the admin account.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### test_vms

A map defining test VMs.

Values contain the following elements:

- `name`: a name of the VM
- `vnet_key`: a key describing a VNET defined in `var.vnets`
- `subnet_key`: a key describing a subnet found in a VNET definition



Type: 

```hcl
map(object({
    name       = string
    vnet_key   = string
    subnet_key = string
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### bastions

A map containing Azure Bastion definitions.

This map follows resource definition convention, following values are available:
- `name`: Bastion name
- `vnet_key`: a key describing a VNET defined in `var.vnets`. This VNET should already have an existing subnet called `AzureBastionSubnet` (the name is hardcoded by Microsoft).
- `subnet_key`: a key pointing to a subnet dedicated to a Bastion deployment (the name should be `AzureBastionSubnet`.)



Type: 

```hcl
map(object({
    name       = string
    vnet_key   = string
    subnet_key = string
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>


<!-- END_TF_DOCS -->