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
  
  For detailed documentation on each property refer to [module documentation](../vnet/README.md)

  - `create_virtual_network`  - (`bool`, optional, defaults to `true`) when set to `true` will create a VNET, `false` will source
                                an existing VNET.
  - `name`                    - (`string`, required) a name of a VNET. In case `create_virtual_network = false` this should be a
                                full resource name, including prefixes.
  - `address_space`           - (`list`, required when `create_virtual_network = false`) a list of CIDRs for a newly created VNET.
  - `dns_servers`             - (`list`, optional, defaults to module defaults) a list of IP addresses of custom DNS servers
                                (by default Azure DNS is used).
  - `vnet_encryption`         - (`string`, optional, defaults to module default) enables Azure Virtual Network Encryption when
                                set, only possible value at the moment is `AllowUnencrypted`. When set to `null`, the feature is
                                disabled.
  - `ddos_protection_plan_id` - (`string`, optional, defaults to `null`) ID of an existing Azure Network DDOS Protection Plan to
                                be associated with the VNET.
  - `hub_resource_group_name` - (`string`, optional) name of the Resource Group hosting the hub/transit infrastructure. This
                                value is necessary to create peering between the spoke and the hub VNET.
  - `hub_vnet_name`           - (`string`, optional) Name of the hub/transit VNET. This value is required to create peering
                                between the spoke and the hub VNET.
  - `network_security_groups` - (`map`, optional) map of Network Security Groups to create, for details see
                                [VNET module documentation](../vnet/README.md#network_security_groups).
  - `route_tables`            - (`map`, optional) map of Route Tables to create, for details see
                                [VNET module documentation](../vnet/README.md#route_tables).
  - `subnets`                 - (`map`, optional) map of Subnets to create or source, for details see
                                [VNET module documentation](../vnet/README.md#subnets).
  - `local_peer_config`       - (`map`, optional) a map that contains local peer configuration parameters. This value allows to 
                                set `allow_virtual_network_access`, `allow_forwarded_traffic`, `allow_gateway_transit` and 
                                `use_remote_gateways` parameters on the local VNet peering. 
  - `remote_peer_config`      - (`map`, optional) a map that contains remote peer configuration parameters. This value allows to
                                set `allow_virtual_network_access`, `allow_forwarded_traffic`, `allow_gateway_transit` and 
                                `use_remote_gateways` parameters on the remote VNet peering.                  
  EOF
  type = map(object({
    create_virtual_network  = optional(bool, true)
    name                    = string
    address_space           = optional(list(string))
    dns_servers             = optional(list(string))
    vnet_encryption         = optional(string)
    ddos_protection_plan_id = optional(string)
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
    subnets = optional(map(object({
      create                          = optional(bool, true)
      name                            = string
      address_prefixes                = optional(list(string), [])
      network_security_group_key      = optional(string)
      route_table_key                 = optional(string)
      enable_storage_service_endpoint = optional(bool, false)
    })), {})
    local_peer_config = optional(object({
      allow_virtual_network_access = optional(bool, true)
      allow_forwarded_traffic      = optional(bool, true)
      allow_gateway_transit        = optional(bool, false)
      use_remote_gateways          = optional(bool, false)
    }), {})
    remote_peer_config = optional(object({
      allow_virtual_network_access = optional(bool, true)
      allow_forwarded_traffic      = optional(bool, true)
      allow_gateway_transit        = optional(bool, false)
      use_remote_gateways          = optional(bool, false)
    }), {})
  }))
}

variable "load_balancers" {
  description = <<-EOF
  A map containing configuration for all (both private and public) Load Balancers.

  This is a brief description of available properties. For a detailed one please refer to
  [module documentation](../loadbalancer/README.md).

  Following properties are available:

  - `name`                    - (`string`, required) a name of the Load Balancer.
  - `vnet_key`                - (`string`, optional, defaults to `null`) a key pointing to a VNET definition in the `var.vnets`
                                map that stores the Subnet described by `subnet_key`.
  - `zones`                   - (`list`, optional, defaults to module default) a list of zones for Load Balancer's frontend IP
                                configurations.
  - `backend_name`            - (`string`, required) a name of the backend pool to create.
  - `health_probes`           - (`map`, optional, defaults to `null`) a map defining health probes that will be used by load
                                balancing rules, please refer to
                                [module documentation](../loadbalancer/README.md#health_probes) for more specific use cases and
                                available properties.
  - `nsg_auto_rules_settings` - (`map`, optional, defaults to `null`) a map defining a location of an existing NSG rule that will
                                be populated with `Allow` rules for each load balancing rule (`in_rules`), please refer to
                                [module documentation](../loadbalancer/README.md#nsg_auto_rules_settings) for available
                                properties. 
                                
    Please note that in this example two additional properties are available:

    - `nsg_vnet_key` - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to a VNET definition in the
                       `var.vnets` map that stores the NSG described by `nsg_key`.
    - `nsg_key`      - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to an NSG definition in the
                       `var.vnets` map.

  - `frontend_ips`            - (`map`, optional, defaults to `{}`) a map containing frontend IP configuration with respective
                                `in_rules` and `out_rules`, please refer to
                                [module documentation](../loadbalancer/README.md#frontend_ips) for available properties.

    **Note!** \
    In this example the `subnet_id` is not available directly, another property has been introduced instead:

    - `subnet_key` - (`string`, optional, defaults to `null`) a key pointing to a Subnet definition in the `var.vnets` map.
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    name         = string
    vnet_key     = optional(string)
    zones        = optional(list(string))
    backend_name = optional(string)
    health_probes = optional(map(object({
      name                = string
      protocol            = string
      port                = optional(number)
      probe_threshold     = optional(number)
      interval_in_seconds = optional(number)
      request_path        = optional(string)
    })))
    nsg_auto_rules_settings = optional(object({
      nsg_name                = optional(string)
      nsg_vnet_key            = optional(string)
      nsg_key                 = optional(string)
      nsg_resource_group_name = optional(string)
      source_ips              = list(string)
      base_priority           = optional(number)
    }))
    frontend_ips = optional(map(object({
      name                          = string
      subnet_key                    = optional(string)
      create_public_ip              = optional(bool, false)
      public_ip_name                = optional(string)
      public_ip_resource_group_name = optional(string)
      public_ip_id                  = optional(string)
      public_ip_address             = optional(string)
      public_ip_prefix_id           = optional(string)
      public_ip_prefix_address      = optional(string)
      private_ip_address            = optional(string)
      gwlb_fip_id                   = optional(string)
      in_rules = optional(map(object({
        name                = string
        protocol            = string
        port                = number
        backend_port        = optional(number)
        health_probe_key    = optional(string)
        floating_ip         = optional(bool)
        session_persistence = optional(string)
        nsg_priority        = optional(number)
      })), {})
      out_rules = optional(map(object({
        name                     = string
        protocol                 = string
        allocated_outbound_ports = optional(number)
        enable_tcp_reset         = optional(bool)
        idle_timeout_in_minutes  = optional(number)
      })), {})
    })), {})
  }))
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

  - `name`               - (`string`, required) a name of the spoke VM.
  - `interface_name`     - (`string`, required) a name of the spoke VM's network interface.
  - `disk_name`          - (`string`, required) a name of the OS disk.
  - `vnet_key`           - (`string`, required) a key describing a VNET defined in `var.vnets`.
  - `subnet_key`         - (`string`, required) a key describing a Subnet found in a VNET definition.
  - `load_balancer_key`  - (`string`, optional) a key of a Load Balancer defined in `var.load_balancers` variable, network
                           interface that has this property defined will be added to the Load Balancer's backend pool.
  - `private_ip_address` - (`string`, optional) static private IP to assign to the interface. When skipped Azure will assign one
                           dynamically. Keep in mind that a dynamic IP is guarantied not to change as long as the VM is running.
                           Any stop/deallocate/restart operation might cause the IP to change.
  - `size`               - (`string`, optional, default to `Standard_D1_v2`) a size of the spoke VM.
  - `image`              - (`map`, optional) a map defining basic spoke VM image configuration. By default, latest Bitnami
                           WordPress VM is deployed.
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
  - `custom_data`        - (`string`, optional) custom data to pass to the spoke VM. This can be used as cloud-init for Linux
                           systems.
  EOF
  type = map(object({
    name               = string
    interface_name     = string
    disk_name          = string
    vnet_key           = string
    subnet_key         = string
    load_balancer_key  = optional(string)
    private_ip_address = optional(string)
    size               = optional(string, "Standard_D1_v2")
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
  - `name`                          - (`string`, required) an Azure Bastion name.
  - `create_public_ip`              - (`bool`, optional, defaults to `true`) controls if the Public IP resource is created or
                                      sourced.
  - `public_ip_name`                - (`string`, optional) name of the Public IP resource, required unless `public_ip` module and 
                                      `public_ip_id` property are used.
  - `public_ip_resource_group_name` - (`string`, optional) name of the Resource Group hosting the Public IP resource, used only
                                      for sourced resources.
  - `public_ip_id`                  - (`string`, optional) ID of the Public IP to associate with the Bastion. Property is used
                                      when Public IP is not created or sourced within this module.
  - `vnet_key`                      - (`string`, required) a key describing a VNET defined in `var.vnets`. This VNET should
                                      already have an existing subnet called `AzureBastionSubnet` (the name is hardcoded
                                      by Microsoft).
  - `subnet_key`                    - (`string`, required) a key pointing to a Subnet dedicated to the Bastion deployment.
  EOF
  type = map(object({
    name                          = string
    create_public_ip              = optional(bool, true)
    public_ip_name                = optional(string)
    public_ip_resource_group_name = optional(string)
    public_ip_id                  = optional(string)
    vnet_key                      = string
    subnet_key                    = string
  }))
  validation { # public_ip_id, public_ip_name
    condition = alltrue([
      for _, v in var.bastions : v.public_ip_name != null || v.public_ip_id != null
    ])
    error_message = <<-EOF
    Either `public_ip_name` or `public_ip_id` property must be set.
    EOF
  }
  validation { # public_ip_id, create_public_ip, public_ip_name
    condition = alltrue([
      for _, v in var.bastions : v.create_public_ip == false && v.public_ip_name == null if v.public_ip_id != null
    ])
    error_message = <<-EOF
    When using `public_ip_id` property, `create_public_ip` must be set to `false` and `public_ip_name` must not be set.
    EOF
  }
}
