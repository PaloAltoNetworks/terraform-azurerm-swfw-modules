<!-- BEGIN_TF_DOCS -->
# Palo Alto Networks Test Infrastructure Module for Azure

A Terraform module for deploying a Test Infrastructure in Azure cloud, containing peered VNETs with test Bitnami-based VMs
running WordPress and Azure Bastion jumphosts for secure access to the test VMs.

## Usage

For usage please refer to any reference architecture example.

## Module's Required Inputs

Name | Type | Description
--- | --- | ---
[`resource_group_name`](#resource_group_name) | `string` | The name of the Resource Group to use.
[`location`](#location) | `string` | The name of the Azure region to deploy the resources in.
[`vnets`](#vnets) | `map` | A map defining VNETs.
[`authentication`](#authentication) | `object` | A map defining authentication details for spoke VMs.
[`spoke_vms`](#spoke_vms) | `map` | A map defining spoke VMs for testing.
[`bastions`](#bastions) | `map` | A map containing Azure Bastion definition.


## Module's Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_resource_group`](#create_resource_group) | `bool` | When set to `true` it will cause a Resource Group creation.
[`tags`](#tags) | `map` | The map of tags to assign to all created resources.
[`hub_resource_group_name`](#hub_resource_group_name) | `string` | Name of the Resource Group hosting the hub/transit infrastructure.
[`hub_vnet_name`](#hub_vnet_name) | `string` | Name of the hub/transit VNET.



## Module's Outputs

Name |  Description
--- | ---
`vm_private_ips` | A map of private IPs assigned to test VMs.

## Module's Nameplate


Requirements needed by this module:

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 3.80


Providers used in this module:

- `azurerm`, version: ~> 3.80


Modules used in this module:
Name | Version | Source | Description
--- | --- | --- | ---
`vnet` | - | ../vnet | https://github.com/PaloAltoNetworks/terraform-azurerm-swfw-modules/blob/main/modules/vnet/README.md
`vnet_peering` | - | ../vnet_peering | https://github.com/PaloAltoNetworks/terraform-azurerm-swfw-modules/blob/main/modules/vnet_peering/README.md


Resources used in this module:

- `bastion_host` (managed)
- `linux_virtual_machine` (managed)
- `network_interface` (managed)
- `public_ip` (managed)
- `resource_group` (managed)
- `resource_group` (data)

## Inputs/Outpus details

### Required Inputs



#### resource_group_name

The name of the Resource Group to use.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### location

The name of the Azure region to deploy the resources in.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>


#### vnets

A map defining VNETs.
  
For detailed documentation on each property refer to [module documentation](../vnet/README.md)

- `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, 
                              `false` will source an existing VNET.
- `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = `false` this should be
                              a full resource name, including prefixes.
- `address_space`           - (`list(string)`, required when `create_virtual_network = `false`) a list of CIDRs for a newly
                              created VNET
- `resource_group_name`     - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which
                              the VNET will reside or is sourced from
- `create_subnets`          - (`bool`, optional, defaults to `true`) if `true`, create Subnets inside the Virtual Network,
                              otherwise use source existing subnets
- `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                              [VNET module documentation](../vnet/README.md#subnets)
- `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                              [VNET module documentation](../vnet/README.md#network_security_groups)
- `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                              [VNET module documentation](../vnet/README.md#route_tables)


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



#### authentication

A map defining authentication details for spoke VMs.
  
Following properties are available:
- `username` - (`string`, optional, defaults to `bitnami`) the initial administrative spoke VM username.
- `password` - (`string`, required) the initial administrative spoke VM password.
  


Type: 

```hcl
object({
    username = optional(string, "bitnami")
    password = string
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

#### spoke_vms

A map defining spoke VMs for testing.

Values contain the following elements:

- `name`           - (`string`, required) a name of the spoke VM.
- `interface_name` - (`string`, required) a name of the spoke VM's network interface.
- `disk_name`      - (`string`, required) a name of the OS disk.
- `vnet_key`       - (`string`, required) a key describing a VNET defined in `var.vnets`.
- `subnet_key`     - (`string`, required) a key describing a Subnet found in a VNET definition.
- `size`           - (`string`, optional, default to `Standard_D1_v2`) a size of the spoke VM.
- `image`          - (`map`, optional) a map defining basic spoke VM image configuration. By default, latest Bitnami WordPress
                     VM is deployed.
  - `publisher`               - (`string`, optional, defaults to `bitnami`) the Azure Publisher identifier for an image which
                                should be deployed.
  - `offer`                   - (`string`, optional, defaults to `wordpress`) the Azure Offer identifier corresponding to a 
                                published image.
  - `sku`                     - (`string`, optional, defaults to `4-4`) the Azure SKU identifier corresponding to a published
                                image and offer.
  - `version`                 - (`string`, optional, defaults to `latest`) the version of the image available on Azure
                                Marketplace.
  - `enable_marketplace_plan` - (`bool`, optional, defaults to `true`) when set to `true` accepts the license for an offer/plan
                                on Azure Marketplace.
- `custom_data`    - (`string`, optional) custom data to pass to the spoke VM. This can be used as cloud-init for Linux systems.
  


Type: 

```hcl
map(object({
    name           = string
    interface_name = string
    disk_name      = string
    vnet_key       = string
    subnet_key     = string
    size           = optional(string, "Standard_D1_v2")
    image = object({
      publisher               = optional(string, "bitnami")
      offer                   = optional(string, "wordpress")
      sku                     = optional(string, "4-4")
      version                 = optional(string, "latest")
      enable_marketplace_plan = optional(bool, true)
    })
    custom_data = optional(string)
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>

#### bastions

A map containing Azure Bastion definition.

This map follows resource definition convention, following values are available:
- `name`           - (`string`, required) an Azure Bastion name.
- `public_ip_name` - (`string`, required) a name of the public IP associated with the Bastion.
- `vnet_key`       - (`string`, required) a key describing a VNET defined in `var.vnets`. This VNET should already have an 
                     existing subnet called `AzureBastionSubnet` (the name is hardcoded by Microsoft).
- `subnet_key`     - (`string`, required) a key pointing to a Subnet dedicated to the Bastion deployment.



Type: 

```hcl
map(object({
    name           = string
    public_ip_name = string
    vnet_key       = string
    subnet_key     = string
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>



### Optional Inputs


#### create_resource_group

When set to `true` it will cause a Resource Group creation. Name of the newly specified RG is controlled by `resource_group_name`.
When set to `false` the `resource_group_name` parameter is used to specify a name of an existing Resource Group.


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>



#### tags

The map of tags to assign to all created resources.

Type: map(string)

Default value: `map[]`

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




<!-- END_TF_DOCS -->