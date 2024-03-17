variable "create_resource_group" {
  description = <<-EOF
  When set to `true` it will cause a Resource Group creation. Name of the newly specified RG is controlled by
  `resource_group_name`. When set to `false` the `resource_group_name` parameter is used to specify a name of an existing
  Resource Group.
  EOF
  default     = true
  type        = bool
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

variable "vnets" {
  description = <<-EOF
  A map defining VNETs.
  
  For detailed documentation on each property refer to [module documentation](../../modules/vnet/README.md)

  - `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, `false` will source
                                an existing VNET.
  - `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = false` this should be a
                                full resource name, including prefixes.
  - `address_space`           - (`list`, required when `create_virtual_network = false`) a list of CIDRs for a newly created VNET.
  - `resource_group_name`     - (`string`, optional, defaults to current RG) a name of an existing Resource Group in which the
                                VNET will reside or is sourced from.
  - `create_subnets`          - (`bool`, optional, defaults to `true`) if `true`, create Subnets inside the Virtual Network,
                                otherwise use source existing subnets.
  - `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                                [VNET module documentation](../../modules/vnet/README.md#subnets).
  - `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#network_security_groups).
  - `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                                [VNET module documentation](../../modules/vnet/README.md#route_tables).
  EOF
  type = map(object({
    name                    = string
    create_virtual_network  = optional(bool, true)
    address_space           = optional(list(string))
    hub_resource_group_name = optional(string)
    hub_vnet_name           = optional(string)
    network_security_groups = optional(map(object({
      name = string
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
      name                          = string
      disable_bgp_route_propagation = optional(bool)
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
}

variable "hub_resource_group_name" {
  description = <<-EOF
  Name of the Resource Group hosting the hub/transit infrastructure. This value is required to create peering between the spoke
  and the hub VNET.
  EOF
  type        = string
  default     = null
}

variable "hub_vnet_name" {
  description = "Name of the hub/transit VNET. This value is required to create peering between the spoke and the hub VNET."
  type        = string
  default     = null
}

variable "authentication" {
  description = <<-EOF
  A map defining authentication details for spoke VMs.
  
  Following properties are available:
  - `username` - (`string`, optional, defaults to `bitnami`) the initial administrative spoke VM username.
  - `password` - (`string`, required) the initial administrative spoke VM password.
  EOF
  type = object({
    username = optional(string, "bitnami")
    password = string
  })
}

variable "spoke_vms" {
  description = <<-EOF
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
  EOF
  type = map(object({
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
}

variable "bastions" {
  description = <<-EOF
  A map containing Azure Bastion definition.

  This map follows resource definition convention, following values are available:
  - `name`           - (`string`, required) an Azure Bastion name.
  - `public_ip_name` - (`string`, required) a name of the public IP associated with the Bastion.
  - `vnet_key`       - (`string`, required) a key describing a VNET defined in `var.vnets`. This VNET should already have an 
                       existing subnet called `AzureBastionSubnet` (the name is hardcoded by Microsoft).
  - `subnet_key`     - (`string`, required) a key pointing to a Subnet dedicated to the Bastion deployment.
  EOF
  type = map(object({
    name           = string
    public_ip_name = string
    vnet_key       = string
    subnet_key     = string
  }))
}
