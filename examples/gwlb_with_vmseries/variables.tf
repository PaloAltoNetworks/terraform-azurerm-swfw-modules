# GENERAL

variable "name_prefix" {
  description = <<-EOF
  A prefix that will be added to all created resources.
  There is no default delimiter applied between the prefix and the resource name.
  Please include the delimiter in the actual prefix.

  Example:
  ```
  name_prefix = "test-"
  ```
  
  **Note!** \
  This prefix is not applied to existing resources. If you plan to reuse i.e. a VNET please specify it's full name,
  even if it is also prefixed with the same value as the one in this property.
  EOF
  default     = ""
  type        = string
}

variable "create_resource_group" {
  description = <<-EOF
  When set to `true` it will cause a Resource Group creation.
  Name of the newly specified RG is controlled by `resource_group_name`.
  
  When set to `false` the `resource_group_name` parameter is used to specify a name of an existing Resource Group.
  EOF
  default     = true
  type        = bool
}

variable "resource_group_name" {
  description = "Name of the Resource Group."
  type        = string
}

variable "region" {
  description = "The Azure region to use."
  type        = string
}

variable "tags" {
  description = "Map of tags to assign to the created resources."
  default     = {}
  type        = map(string)
}

# NETWORK

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
    name                   = string
    resource_group_name    = optional(string)
    create_virtual_network = optional(bool, true)
    address_space          = optional(list(string))
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

# LOAD BALANCING

variable "load_balancers" {
  description = <<-EOF
  A map containing configuration for all (both private and public) Load Balancers.

  This is a brief description of available properties. For a detailed one please refer to
  [module documentation](../../modules/loadbalancer/README.md).

  Following properties are available:

  - `name`                    - (`string`, required) a name of the Load Balancer.
  - `vnet_key`                - (`string`, optional, defaults to `null`) a key pointing to a VNET definition in the `var.vnets`
                                map that stores the Subnet described by `subnet_key`.
  - `zones`                   - (`list`, optional, defaults to module default) a list of zones for Load Balancer's frontend IP
                                configurations.
  - `backend_name`            - (`string`, optional, defaults to "vmseries_backend") a name of the backend pool to create.
  - `health_probes`           - (`map`, optional, defaults to `null`) a map defining health probes that will be used by load
                                balancing rules, please refer to
                                [module documentation](../../modules/loadbalancer/README.md#health_probes) for more specific use
                                cases and available properties.
  - `nsg_auto_rules_settings` - (`map`, optional, defaults to `null`) a map defining a location of an existing NSG rule that will
                                be populated with `Allow` rules for each load balancing rule (`in_rules`), please refer to
                                [module documentation](../../modules/loadbalancer/README.md#nsg_auto_rules_settings) for
                                available properties. 
                                
    Please note that in this example two additional properties are available:

    - `nsg_vnet_key` - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to a VNET definition in the
                       `var.vnets` map that stores the NSG described by `nsg_key`.
    - `nsg_key`      - (`string`, optional, mutually exclusive with `nsg_name`) a key pointing to an NSG definition in the
                       `var.vnets` map.

  - `frontend_ips`            - (`map`, optional, defaults to `{}`) a map containing frontend IP configuration with respective
                                `in_rules` and `out_rules`, please refer to
                                [module documentation](../../modules/loadbalancer/README.md#frontend_ips) for available
                                properties.

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
    backend_name = optional(string, "vmseries_backend")
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
      public_ip_name                = optional(string)
      create_public_ip              = optional(bool, false)
      public_ip_resource_group_name = optional(string)
      private_ip_address            = optional(string)
      gwlb_key                      = optional(string)
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

variable "gateway_load_balancers" {
  description = <<-EOF
  A map with Gateway Load Balancer (GWLB) definitions.

  Following settings are available:
  - `name`          - (`string`, required) name of the Gateway Load Balancer Gateway.
  - `vnet_key`      - (`string`, required) a name (key value) of a VNET defined in `var.vnets` that hosts a subnet this GWLB will
                      be assigned to.
  - `subnet_key`    - (`string`, required) a name (key value) of Subnet the GWLB will be assigned to, defined in `var.vnets` for
                      a VNET described by `vnet_name`.        
  - `frontend_ip`   - (`object`, required) frontend IP configuration, refer to
                      [module's documentation](../../modules/gwlb/README.md) for details.
  - `health_probe`  - (`object`, optional) health probe settings, refer to
                      [module's documentation](../../modules/gwlb/README.md) for details.
  - `backends`      - (`map`, optional) map of backends, refer to
                      [module's documentation](../../modules/gwlb/README.md) for details.
  - `lb_rule`       - (`object`, optional) load balancer rule, refer to 
                      [module's documentation](../../modules/gwlb/README.md) for details.
  EOF
  default     = {}
  type = map(object({
    name  = string
    zones = optional(list(string), ["1", "2", "3"])
    frontend_ip = object({
      name                       = optional(string)
      vnet_key                   = string
      subnet_key                 = string
      private_ip_address         = optional(string)
      private_ip_address_version = optional(string, "IPv4")
    })
    health_probe = optional(object({
      name                = optional(string)
      protocol            = string
      port                = optional(number)
      probe_threshold     = optional(number)
      interval_in_seconds = optional(number)
      request_path        = optional(string, "/")
    }))
    backends = optional(map(object({
      name = optional(string)
      tunnel_interfaces = map(object({
        identifier = number
        port       = number
        protocol   = optional(string, "VXLAN")
        type       = string
      }))
    })))
    lb_rule = optional(object({
      name              = optional(string)
      load_distribution = optional(string, "Default")
    }))
  }))
}

# VM-SERIES

variable "availability_sets" {
  description = <<-EOF
  A map defining availability sets. Can be used to provide infrastructure high availability when zones cannot be used.

  Following properties are supported:

  - `name`                - (`string`, required) name of the Application Insights.
  - `update_domain_count` - (`number`, optional, defaults to Azure default) specifies the number of update domains that are used.
  - `fault_domain_count`  - (`number`, optional, defaults to Azure default) specifies the number of fault domains that are used.
  
  **Note!** \
  Please keep in mind that Azure defaults are not working for every region (especially the small ones, without any Availability
  Zones). Please verify how many update and fault domain are supported in a region before deploying this resource.
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    name                = string
    update_domain_count = optional(number)
    fault_domain_count  = optional(number)
  }))
}

variable "ngfw_metrics" {
  description = <<-EOF
  A map controlling metrics-relates resources.

  When set to explicit `null` (default) it will disable any metrics resources in this deployment.

  When defined it will either create or source a Log Analytics Workspace and create Application Insights instances (one per each
  Scale Set). All instances will be automatically connected to the workspace. The name of the Application Insights instance will
  be derived from the Scale Set name and suffixed with `-ai`.

  All the settings available below are common to the Log Analytics Workspace and Application Insight instances.

  Following properties are available:

  - `name`                      - (`string`, required) name of the (common) Log Analytics Workspace.
  - `create_workspace`          - (`bool`, optional, defaults to `true`) controls whether we create or source an existing Log
                                  Analytics Workspace.
  - `resource_group_name`       - (`string`, optional, defaults to `var.resource_group_name`) name of the Resource Group hosting
                                  the Log Analytics Workspace.
  - `sku`                       - (`string`, optional, defaults to module default) the SKU of the Log Analytics Workspace.
  - `metrics_retention_in_days` - (`number`, optional, defaults to module default) workspace and insights data retention in days,
                                  possible values are between 30 and 730. For sourced Workspaces this applies only to the
                                  Application Insights instances.
  EOF
  default     = null
  type = object({
    name                      = string
    create_workspace          = optional(bool, true)
    resource_group_name       = optional(string)
    sku                       = optional(string)
    metrics_retention_in_days = optional(number)
  })
}

variable "bootstrap_storages" {
  description = <<-EOF
  A map defining Azure Storage Accounts used to host file shares for bootstrapping NGFWs.

  You can create or re-use an existing Storage Account and/or File Share. For details on all available properties please refer to
  [module's documentation](../../modules/bootstrap/README.md). Following is just an extract of the most important ones:

  - `name`                      - (`string`, required) name of the Storage Account that will be created or sourced.

    **Note** \
    For new Storage Accounts this name will not be prefixed with `var.name_prefix`. \
    Please note the limitations on naming. This has to be a globally unique name, between 3 and 63 chars, only lower-case letters
    and numbers.

  - `resource_group_name`       - (`string`, optional, defaults to `null`) name of the Resource Group that hosts (sourced) or
                                  will host (created) a Storage Account. When skipped the code will fall back to
                                  `var.resource_group_name`.
  - `storage_account`           - (`map`, optional, defaults to `{}`) a map controlling basic Storage Account configuration.
                                  
    The property you should pay attention to is:

    - `create` - (`bool`, optional, defaults to module default) controls if the Storage Account specified in the `name` property
                 will be created or sourced.

    For detailed documentation see [module's documentation](../../modules/bootstrap/README.md#storage_account).

  - `storage_network_security`  - (`map`, optional, defaults to `{}`) a map defining network security settings for a **new**
                                  storage account. 
                                  
    The properties you should pay attention to are:

    - `allowed_subnet_keys` - (`list`, optional, defaults to `[]`) a list of keys pointing to Subnet definitions in the
                              `var.vnets` map. These Subnets will have dedicated access to the Storage Account. For this to work
                              they also need to have the Storage Account Service Endpoint enabled.
    - `vnet_key`            - (`string`, optional) a key pointing to a VNET definition in the `var.vnets` map that stores the
                              Subnets described in `allowed_subnet_keys`.

    For detailed documentation see [module's documentation](../../modules/bootstrap/README.md#storage_network_security).
                            
  - `file_shares_configuration` - (`map`, optional, defaults to `{}`) a map defining common File Share setting.
                                  
    The properties you should pay attention to are:

    - `create_file_shares`            - (`bool`, optional, defaults to module default) controls if the File Shares defined in the
                                        `file_shares` property will be created or sourced.
    - `disable_package_dirs_creation` - (`bool`, optional, defaults to module default) for sourced File Shares, controls if the
                                        bootstrap package folder structure will be created.

    For detailed documentation see [module's documentation](../../modules/bootstrap/README.md#file_shares_configuration).

  - `file_shares`               - (`map`, optional, defaults to `{}`) a map that holds File Shares and bootstrap package
                                  configuration. For detailed description see
                                  [module's documentation](../../modules/bootstrap/README.md#file_shares).
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    name                = string
    resource_group_name = optional(string)
    storage_account = optional(object({
      create           = optional(bool)
      replication_type = optional(string)
      kind             = optional(string)
      tier             = optional(string)
    }), {})
    storage_network_security = optional(object({
      min_tls_version     = optional(string)
      allowed_public_ips  = optional(list(string))
      vnet_key            = optional(string)
      allowed_subnet_keys = optional(list(string), [])
    }), {})
    file_shares_configuration = optional(object({
      create_file_shares            = optional(bool)
      disable_package_dirs_creation = optional(bool)
      quota                         = optional(number)
      access_tier                   = optional(string)
    }), {})
    file_shares = optional(map(object({
      name                   = string
      bootstrap_package_path = optional(string)
      bootstrap_files        = optional(map(string))
      bootstrap_files_md5    = optional(map(string))
      quota                  = optional(number)
      access_tier            = optional(string)
    })), {})
  }))
}

variable "vmseries" {
  description = <<-EOF
  A map defining Azure Virtual Machines based on Palo Alto Networks Next Generation Firewall image.

  For details and defaults for available options please refer to the [`vmseries`](../../modules/vmseries/README.md) module.

  The most basic properties are as follows:

  - `name`            - (`string`, required) name of the VM, will be prefixed with the value of `var.name_prefix`.
  - `vnet_key`        - (`string`, required) a key of a VNET defined in `var.vnets`. This is the VNET that hosts subnets used to
                        deploy network interfaces for deployed VM.
  - `authentication`  - (`map`, optional, defaults to example defaults) authentication settings for the deployed VM.

    The `authentication` property is optional and holds the firewall admin access details. By default, standard username
    `panadmin` will be set and a random password will be auto-generated for you (available in Terraform outputs).

    **Note!** \
    The `disable_password_authentication` property is by default `false` in this example. When using this value, you don't have
    to specify anything but you can still additionally pass SSH keys for authentication. You can however set this property to 
    `true`, then you have to specify `ssh_keys` property.

    For all properties and their default values see [module's documentation](../../modules/vmseries/README.md#authentication).

  - `image`           - (`map`, required) properties defining a base image used by the deployed VM. The `image` property is
                        required but there are only 2 properties (mutually exclusive) that have to be set, either:

    - `version`   - (`string`, optional) describes the PAN-OS image version from Azure Marketplace.
    - `custom_id` - (`string`, optional) absolute ID of your own custom PAN-OS image.

    For details on all properties refer to [module's documentation](../../modules/vmseries/README.md#image).

  - `virtual_machine` - (`map`, optional, defaults to module default) a map that groups most common VM configuration options. 
                        Most common properties are:

    - `size`              - (`string`, optional, defaults to module default) Azure VM size (type). Consult the *VM-Series
                            Deployment Guide* as only a few selected sizes are supported.
    - `zone`              - (`string`, optional, defaults to module default) the Availability Zone in which the VM and (if
                            deployed) public IP addresses will be created.
    - `disk_type`         - (`string`, optional, defaults to module default) type of a Managed Disk which should be created,
                            possible values are `Standard_LRS`, `StandardSSD_LRS` or `Premium_LRS` (works only for selected
                            `size` values).
    - `bootstrap_options` - (`string`, optional, mutually exclusive with `bootstrap_package`) bootstrap options passed to PAN-OS
                            when launched for the 1st time, for details see module documentation.
    - `bootstrap_package` - (`map`, optional, mutually exclusive with `bootstrap_options`) a map defining content of the
                            bootstrap package.

      **Note!** \
      At least one of `static_files`, `bootstrap_xml_template` or `bootstrap_package_path` is required. You can use a combination
      of all 3. The `bootstrap_package_path` is the less important. For details on this mechanism and for details on the other
      properties see the [`bootstrap` module documentation](../../modules/bootstrap/README.md).

      Following properties are available:

      - `bootstrap_storage_key`  - (`string`, required) a key of a bootstrap storage defined in `var.bootstrap_storages` that
                                   will host bootstrap packages. Each package will be hosted on a separate File Share. The File
                                   Shares will be created automatically, one for each firewall.
      - `static_files`           - (`map`, optional, defaults to `{}`) a map containing files that will be copied to a File
                                   Share, see [`file_shares.bootstrap_files`](../../modules/bootstrap/README.md#file_shares)
                                   property documentation for details.
      - `bootstrap_package_path` - (`string`, optional, defaults to `null`) a path to a folder containing a full bootstrap
                                   package.
      - `bootstrap_xml_template` - (`string`, optional, defaults to `null`) a path to a `bootstrap.xml` template. If this example
                                   is using full bootstrap method, the sample templates are in [`templates`](./templates) folder.

        The templates are used to provide `day0` like configuration which consists of:

        - network interfaces configuration.
        - one or more (depending on the architecture) Virtual Routers configurations. This config contains static routes
          required for the Load Balancer (and Application Gateway, if defined) health checks to work and routes that allow
          Inbound and OBEW traffic.
        - *any-any* security rule.
        - an outbound NAT rule that will allow the Outbound traffic to flow to the Internet.

        **Note!** \
        Day0 configuration is **not meant** to be **secure**. It's here merely to help with the basic firewall setup. When
        `bootstrap_xml_template` is set, one of the following properties might be required.
        
      - `data_snet_key`          - (`string`, required only when `bootstrap_xml_template` is set, defaults to `null`) a key
                                   pointing to a data Subnet definition in `var.vnets` (the `vnet_key` property is used to
                                   identify a VNET). The Subnet definition is used to calculate static routes for a data
                                   Load Balancer health checks.
      - `ai_update_interval`     - (`number`, optional, defaults to `5`) Application Insights update interval, used only when
                                   `ngfw_metrics` module is defined and used in this example. The Application Insights
                                   Instrumentation Key will be populated automatically.
      - `intranet_cidr`          - (`string`, optional, defaults to `null`) a CIDR of the Intranet - combined CIDR of all
                                   private networks. When set it will override the private Subnet CIDR for inbound traffic
                                   static routes.
      
      For details on all properties refer to [module's documentation](../../modules/panorama/README.md#virtual_machine).

  - `interfaces`      - (`list`, required) configuration of all network interfaces. Order of the interfaces does matter - the
                        1<sup>st</sup> interface is the management one. Most common properties are:

    - `name`                    - (`string`, required) name of the network interface (will be prefixed with `var.name_prefix`).
    - `subnet_key`              - (`string`, required) a key of a subnet to which the interface will be assigned as defined in
                                  `var.vnets`. Key identifying the VNET is defined in `virtual_machine.vnet_key` property.
    - `create_public_ip`        - (`bool`, optional, defaults to `false`) create a Public IP for an interface.
    - `load_balancer_key`       - (`string`, optional, defaults to `null`) key of a Load Balancer defined in `var.loadbalancers`
                                  variable, network interface that has this property defined will be added to the Load Balancer's
                                  backend pool.
    - `application_gateway_key` - (`string`, optional, defaults to `null`) key of an Application Gateway defined in `var.appgws`
                                  variable, network interface that has this property defined will be added to the Application
                                  Gateway's backend pool.

    For details on all properties refer to [module's documentation](../../modules/panorama/README.md#interfaces).
  EOF
  default     = {}
  nullable    = false
  type = map(object({
    name     = string
    vnet_key = string
    authentication = optional(object({
      username                        = optional(string, "panadmin")
      password                        = optional(string)
      disable_password_authentication = optional(bool, false)
      ssh_keys                        = optional(list(string), [])
    }), {})
    image = object({
      version                 = optional(string)
      publisher               = optional(string)
      offer                   = optional(string)
      sku                     = optional(string)
      enable_marketplace_plan = optional(bool)
      custom_id               = optional(string)
    })
    virtual_machine = object({
      size              = optional(string)
      bootstrap_options = optional(string)
      bootstrap_package = optional(object({
        bootstrap_storage_key  = string
        static_files           = optional(map(string), {})
        bootstrap_package_path = optional(string)
        bootstrap_xml_template = optional(string)
        data_snet_key          = optional(string)
        ai_update_interval     = optional(number, 5)
        intranet_cidr          = optional(string)
      }))
      zone                         = string
      disk_type                    = optional(string)
      disk_name                    = optional(string)
      avset_key                    = optional(string)
      accelerated_networking       = optional(bool)
      encryption_at_host_enabled   = optional(bool)
      disk_encryption_set_id       = optional(string)
      enable_boot_diagnostics      = optional(bool, true)
      boot_diagnostics_storage_uri = optional(string)
      identity_type                = optional(string)
      identity_ids                 = optional(list(string))
      allow_extension_operations   = optional(bool)
    })
    interfaces = list(object({
      name                          = string
      subnet_key                    = string
      create_public_ip              = optional(bool, false)
      public_ip_name                = optional(string)
      public_ip_resource_group_name = optional(string)
      private_ip_address            = optional(string)
      load_balancer_key             = optional(string)
      gwlb_key                      = optional(string)
      gwlb_backend_key              = optional(string)
      application_gateway_key       = optional(string)
    }))
  }))
  validation { # virtual_machine.bootstrap_options & virtual_machine.bootstrap_package
    condition = alltrue([
      for _, v in var.vmseries :
      v.virtual_machine.bootstrap_options != null && v.virtual_machine.bootstrap_package == null ||
      v.virtual_machine.bootstrap_options == null && v.virtual_machine.bootstrap_package != null
    ])
    error_message = <<-EOF
    Either `bootstrap_options` or `bootstrap_package` property can be set.
    EOF
  }
  validation { # virtual_machine.bootstrap_package
    condition = alltrue([
      for _, v in var.vmseries :
      v.virtual_machine.bootstrap_package.bootstrap_xml_template != null ? (
        v.virtual_machine.bootstrap_package.data_snet_key != null
      ) : true if v.virtual_machine.bootstrap_package != null
    ])
    error_message = <<-EOF
    The `data_snet_key` is required when `bootstrap_xml_template` is set.
    EOF
  }
}

# TEST INFRASTRUCTURE

variable "appvms" {
  description = <<-EOF
  Configuration for sample application VMs.
  EOF
  default     = {}
  type        = any
}
