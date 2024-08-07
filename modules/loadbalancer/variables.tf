variable "name" {
  description = "The name of the Azure Load Balancer."
  type        = string
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

variable "zones" {
  description = <<-EOF
  Controls zones for Load Balancer's fronted IP configurations.

  For:

  - public IPs  - these are zones in which the Public IP resource is available.
  - private IPs - these are zones to which Azure will deploy paths leading to Load Balancer frontend IPs (all frontends are 
                  affected).

  Setting this variable to explicit `null` disables a zonal deployment.
  This can be helpful in regions where Availability Zones are not available.

  For public Load Balancers, since this setting controls also Availability Zones for Public IPs, you need to specify all zones
  available in a region (typically 3): `["1","2","3"]`.
  EOF
  default     = ["1", "2", "3"]
  type        = list(string)
}

variable "backend_name" {
  description = "The name of the backend pool to create. All frontends of the Load Balancer always use the same backend."
  type        = string
  validation {
    condition     = can(regex("^\\w[\\w\\_\\.\\-]{0,78}(\\w|\\_)$", var.backend_name))
    error_message = <<-EOF
    The `backend_name` property can be maximum 80 chars long and must consist of word characters, dots, underscores and dashes.
    It has to start with a word character and end with one or with an underscore.
    EOF
  }
}

variable "frontend_ips" {
  description = <<-EOF
  A map of objects describing Load Balancer Frontend IP configurations with respective inbound and outbound rules.
  
  Each Frontend IP configuration can have multiple rules assigned.
  They are defined in a maps called `in_rules` and `out_rules` for inbound and outbound rules respectively.

  Since this module can be used to create either a private or a public Load Balancer some properties can be mutually exclusive.
  To ease configuration they were grouped per Load Balancer type.

  Private Load Balancer:

  - `name`                - (`string`, required) name of a frontend IP configuration.
  - `subnet_id`           - (`string`, required) an ID of an existing subnet that will host the private Load Balancer.
  - `private_ip_address`  - (`string`, required) the IP address of the Load Balancer.
  - `in_rules`            - (`map`, optional, defaults to `{}`) a map defining inbound rules, see details below.
  - `gwlb_fip_id`         - (`string`, optional, defaults to `null`) an ID of a frontend IP configuration of a
                            Gateway Load Balancer.

  Public Load Balancer:

  - `name`                          - (`string`, required) name of a frontend IP configuration.
  - `create_public_ip`              - (`bool`, optional, defaults to `false`) when set to `true` a new Public IP will be
                                      created, otherwise an existing resource will be used;
                                      in both cases the name of the resource is controlled by `public_ip_name` property.
  - `public_ip_name`                - (`string`, optional) name of a Public IP resource, required unless `public_ip` module and
                                      `public_ip_id` property are used.
  - `public_ip_resource_group_name` - (`string`, optional, defaults to the Load Balancer's RG) name of a Resource Group
                                      hosting an existing Public IP resource.
  - `public_ip_id`                  - (`string`, optional, defaults to `null`) ID of the Public IP Address to associate with the
                                      Frontend. Property is used when Public IP is not created or sourced within this module.
  - `public_ip_address`             - (`string`, optional, defaults to `null`) IP address of the Public IP to associate with the
                                      Frontend. Property is used when Public IP is not created or sourced within this module.
  - `public_ip_prefix_id`           - (`string`, optional, defaults to `null`) ID of the Public IP Prefix to associate with the
                                      Frontend. Property is used when you need to source Public IP Prefix.
  - `public_ip_prefix_address`      - (`string`, optional, defaults to `null`) IP address of the Public IP Prefix to associate
                                      with the Frontend. Property is used when you need to source Public IP Prefix.
  - `in_rules`                      - (`map`, optional, defaults to `{}`) a map defining inbound rules, see details below.
  - `out_rules`                     - (`map`, optional, defaults to `{}`) a map defining outbound rules, see details below.

  Below are the properties for the `in_rules` map:

  - `name`                - (`string`, required) a name of an inbound rule.
  - `protocol`            - (`string`, required) communication protocol, either 'Tcp', 'Udp' or 'All'.
  - `port`                - (`number`, required) communication port, this is both the front- and the backend port
                            if `backend_port` is not set; value of `0` means all ports.
  - `backend_port`        - (`number`, optional, defaults to `null`) this is the backend port to forward traffic
                            to in the backend pool.
  - `health_probe_key`    - (`string`, optional, defaults to `default`) a key from the `var.health_probes` map defining
                            a health probe to use with this rule.
  - `floating_ip`         - (`bool`, optional, defaults to `true`) enables floating IP for this rule.
  - `session_persistence` - (`string`, optional, defaults to `Default`) controls session persistance/load distribution,
                            three values are possible:
    - `Default`          - this is the 5 tuple hash.
    - `SourceIP`         - a 2 tuple hash is used.
    - `SourceIPProtocol` - a 3 tuple hash is used.
  - `nsg_priority`        - (number, optional, defaults to `null`) this becomes a priority of an auto-generated NSG rule,
                            when skipped the rule priority will be auto-calculated. For more details on auto-generated NSG rules
                            see [`nsg_auto_rules_settings`](#nsg_auto_rules_settings).

  Below are the properties for `out_rules` map. 
  
  **Warning!** \
  Setting at least one `out_rule` switches the outgoing traffic from SNAT to outbound rules. Keep in mind that since we use a
  single backend, and you cannot mix SNAT and outbound rules traffic in rules using the same backend, setting one `out_rule`
  switches the outgoing traffic route for **ALL** `in_rules`.

  - `name`                      - (`string`, required) a name of an outbound rule.
  - `protocol`                  - (`string`, required) protocol used by the rule. One of `All`, `Tcp` or `Udp` is accepted.
  - `allocated_outbound_ports`  - (`number`, optional, defaults to `null`) number of ports allocated per instance,
                                  when skipped provider defaults will be used (`1024`),
                                  when set to `0` port allocation will be set to default number (Azure defaults);
                                  maximum value is `64000`.
  - `enable_tcp_reset`          - (`bool`, optional, defaults to Azure defaults) ignored when `protocol` is set to `Udp`.
  - `idle_timeout_in_minutes`   - (`number`, optional, defaults to Azure defaults) TCP connection timeout in minutes (between 4 
                                  and 120) in case the connection is idle, ignored when `protocol` is set to `Udp`.

  Examples

  ```hcl
  # rules for a public Load Balancer, reusing an existing Public IP and doing port translation
  frontend_ips = {
    pip_existing = {
      create_public_ip              = false
      public_ip_name                = "my_ip"
      public_ip_resource_group_name = "my_rg_name"
      in_rules = {
        HTTP = {
          port         = 80
          protocol     = "Tcp"
          backend_port = 8080
        }
      }
    }
  }

  # rules for a private Load Balancer, one HA PORTs rule
  frontend_ips = {
    internal = {
      subnet_id                     = azurerm_subnet.this.id
      private_ip_address            = "192.168.0.10"
      in_rules = {
        HA_PORTS = {
          port         = 0
          protocol     = "All"
        }
      }
    }
  }

  # rules for a public Load Balancer, session persistance with 2 tuple hash, outbound rule defined
  frontend_ips = {
    rule_1 = {
      create_public_ip = true
      in_rules = {
        HTTP = {
          port     = 80
          protocol = "Tcp"
          session_persistence = "SourceIP"
        }
      }
    }
    out_rules = {
      "outbound_tcp" = {
        protocol                 = "Tcp"
        allocated_outbound_ports = 2048
        enable_tcp_reset         = true
        idle_timeout_in_minutes  = 10
      }
    }
  }
  ```
  EOF
  type = map(object({
    name                          = string
    create_public_ip              = optional(bool, false)
    public_ip_name                = optional(string)
    public_ip_resource_group_name = optional(string)
    public_ip_id                  = optional(string)
    public_ip_address             = optional(string)
    public_ip_prefix_id           = optional(string)
    public_ip_prefix_address      = optional(string)
    subnet_id                     = optional(string)
    private_ip_address            = optional(string)
    gwlb_fip_id                   = optional(string)
    in_rules = optional(map(object({
      name                = string
      protocol            = string
      port                = number
      backend_port        = optional(number)
      health_probe_key    = optional(string, "default")
      floating_ip         = optional(bool, true)
      session_persistence = optional(string, "Default")
      nsg_priority        = optional(number)
    })), {})
    out_rules = optional(map(object({
      name                     = string
      protocol                 = string
      allocated_outbound_ports = optional(number)
      enable_tcp_reset         = optional(bool)
      idle_timeout_in_minutes  = optional(number)
    })), {})
  }))
  validation { # unified LB type
    condition = !(
      anytrue(
        [for _, fip in var.frontend_ips : fip.public_ip_name != null || fip.public_ip_id != null || fip.public_ip_prefix_id != null]
        ) && anytrue(
        [for _, fip in var.frontend_ips : fip.subnet_id != null]
      )
    )
    error_message = <<-EOF
    All frontends have to be of the same type, either public or private. Please check module's documentation (Usage section) for
    details.
    EOF
  }
  validation { # name
    condition = length(flatten([for _, fip in var.frontend_ips : fip.name])) == length(
      distinct(flatten([for _, fip in var.frontend_ips : fip.name]))
    )
    error_message = <<-EOF
    The `name` property has to be unique among all frontend definitions.
    EOF
  }
  validation { # public_ip_id, public_ip_name
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.public_ip_name != null || fip.public_ip_id != null
      if anytrue([for _, fip in var.frontend_ips : fip.public_ip_name != null || fip.public_ip_id != null])
    ])
    error_message = <<-EOF
    If the LB type is public, all frontends need either `public_ip_name` or `public_ip_id` property set.
    EOF
  }
  validation { # public_ip_id, create_public_ip, public_ip_name
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.create_public_ip == false && fip.public_ip_name == null if fip.public_ip_id != null
    ])
    error_message = <<-EOF
    When using `public_ip_id` property, `create_public_ip` must be set to `false` and `public_ip_name` must not be set.
    EOF
  }
  validation { # public_ip_address, public_ip_id
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.public_ip_id != null if fip.public_ip_address != null
    ])
    error_message = <<-EOF
    When using `public_ip_address` property, `public_ip_id` must be set too.
    EOF
  }
  validation { # public_ip_address
    condition = alltrue([
      for _, fip in var.frontend_ips : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", fip.public_ip_address))
      if fip.public_ip_address != null
    ])
    error_message = <<-EOF
    The `public_ip_address` property should be in IPv4 format.
    EOF
  }
  validation { # public_ip_prefix_id, create_public_ip, public_ip_name
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.create_public_ip == false && fip.public_ip_name == null
      if fip.public_ip_prefix_id != null
    ])
    error_message = <<-EOF
    When using `public_ip_prefix_id` property, `create_public_ip` must be set to `false` and `public_ip_name` must not be set.
    EOF
  }
  validation { # public_ip_id, public_ip_prefix_id
    condition = alltrue(
      [for _, fip in var.frontend_ips : !(fip.public_ip_id != null && fip.public_ip_prefix_id != null)]
    )
    error_message = <<-EOF
    You can set either `public_ip_id` or `public_ip_prefix_id` property, you can't set both.
    EOF
  }
  validation { # public_ip_prefix_address, public_ip_prefix_id
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.public_ip_prefix_id != null if fip.public_ip_prefix_address != null
    ])
    error_message = <<-EOF
    When using `public_ip_prefix_address` property, `public_ip_prefix_id` must be set too.
    EOF
  }
  validation { # public_ip_prefix_address
    condition = alltrue([
      for _, fip in var.frontend_ips : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", fip.public_ip_prefix_address))
      if fip.public_ip_prefix_address != null
    ])
    error_message = <<-EOF
    The `public_ip_prefix_address` property should be in IPv4 format.
    EOF
  }

  validation { # private_ip_address
    condition = alltrue([
      for _, fip in var.frontend_ips : fip.private_ip_address != null if fip.subnet_id != null
    ])
    error_message = <<-EOF
    The `private_ip_address` id required for private Load Balancers.
    EOF
  }
  validation { # private_ip_address
    condition = alltrue([
      for _, fip in var.frontend_ips : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", fip.private_ip_address))
      if fip.private_ip_address != null
    ])
    error_message = <<-EOF
    The `private_ip_address` property should be in IPv4 format.
    EOF
  }
  validation { # in_rules
    condition = alltrue([
      for _, fip in var.frontend_ips : length(fip.in_rules) == 0 if fip.public_ip_prefix_id != null
    ])
    error_message = <<-EOF
    You can't create Inbound Rules for the Frontend with Public IP Prefix.
    EOF
  }
  validation { # in_rules.name
    condition = length(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules : in_rule.name
        ]])) == length(distinct(flatten([
        for _, fip in var.frontend_ips : [
          for _, in_rule in fip.in_rules : in_rule.name
    ]])))
    error_message = <<-EOF
    The `in_rule.name` property has to be unique among all in rules definitions.
    EOF
  }
  validation { # in_rules.protocol
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules : contains(["Tcp", "Udp", "All"], in_rule.protocol)
      ]
    ]))
    error_message = <<-EOF
    The `in_rule.protocol` property should be one of: \"Tcp\", \"Udp\", \"All\".
    EOF
  }
  validation { # in_rules.port
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules : (in_rule.port >= 0 && in_rule.port <= 65535)
      ]
    ]))
    error_message = <<-EOF
    The `in_rule.port` should be a valid TCP port number or `0` for all ports.
    EOF
  }
  validation { # in_rules.backend_port
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules :
        (in_rule.backend_port > 0 && in_rule.backend_port <= 65535)
        if in_rule.backend_port != null
      ]
    ]))
    error_message = <<-EOF
    The `in_rule.backend_port` should be a valid TCP port number.
    EOF
  }
  validation { # in_rules.sessions_persistence
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules : contains(["Default", "SourceIP", "SourceIPProtocol"], in_rule.session_persistence)
      ]
    ]))
    error_message = <<-EOF
    The `in_rule.session_persistence` property should be one of: \"Default\", \"SourceIP\", \"SourceIPProtocol\".
    EOF
  }
  validation { # in_rules.nsg_priority
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, in_rule in fip.in_rules :
        in_rule.nsg_priority >= 100 && in_rule.nsg_priority <= 4000
        if in_rule.nsg_priority != null
      ]
    ]))
    error_message = <<-EOF
    The `in_rule.nsg_priority` property be a number between 100 and 4096.
    EOF
  }
  validation { # out_rules.name
    condition = length(flatten([
      for _, fip in var.frontend_ips : [
        for _, out_rule in fip.out_rules : out_rule.name
        ]])) == length(distinct(flatten([
        for _, fip in var.frontend_ips : [
          for _, out_rule in fip.out_rules : out_rule.name
    ]])))
    error_message = <<-EOF
    The `out_rule.name` property has to be unique among all in rules definitions.
    EOF
  }
  validation { # out_rules.protocol
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, out_rule in fip.out_rules : contains(["Tcp", "Udp", "All"], out_rule.protocol)
      ]
    ]))
    error_message = <<-EOF
    The `out_rule.protocol` property should be one of: \"Tcp\", \"Udp\", \"All\".
    EOF
  }
  validation { # out_rules.allocated_outbound_ports
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, out_rule in fip.out_rules :
        out_rule.allocated_outbound_ports >= 0 && out_rule.allocated_outbound_ports <= 64000
        if out_rule.allocated_outbound_ports != null
      ]
    ]))
    error_message = <<-EOF
    The `out_rule.allocated_outbound_ports` property should can be either `0` or a valid TCP port number with the maximum value
    of 64000.
    EOF
  }
  validation { # out_rules.idle_timeout_in_minutes
    condition = alltrue(flatten([
      for _, fip in var.frontend_ips : [
        for _, out_rule in fip.out_rules :
        out_rule.idle_timeout_in_minutes >= 4 && out_rule.idle_timeout_in_minutes <= 120
        if out_rule.idle_timeout_in_minutes != null
      ]
    ]))
    error_message = <<-EOF
    The `out_rule.idle_timeout_in_minutes` property should can take values between 4 and 120 (minutes).
    EOF
  }
}

variable "health_probes" {
  description = <<-EOF
  Backend's health probe definition.

  When this property is either:

  - not defined at all, or
  - at least one `in_rule` has no health probe specified

  a default, TCP based probe will be created for port 80.

  Following properties are available:

  - `name`                  - (`string`, required) name of the health check probe
  - `protocol`              - (`string`, required) protocol used by the health probe, can be one of "Tcp", "Http" or "Https"
  - `port`                  - (`number`, required for `Tcp`, defaults to protocol port for `Http(s)` probes) port to run
                              the probe against
  - `probe_threshold`       - (`number`, optional, defaults to Azure defaults) number of consecutive probes that decide
                              on forwarding traffic to an endpoint
  - `interval_in_seconds`   - (`number, optional, defaults to Azure defaults) interval in seconds between probes,
                              with a minimal value of 5
  - `request_path`          - (`string`, optional, defaults to `/`) used only for non `Tcp` probes,
                              the URI used to check the endpoint status when `protocol` is set to `Http(s)`
  EOF
  default     = null
  type = map(object({
    name                = string
    protocol            = string
    port                = optional(number)
    probe_threshold     = optional(number)
    interval_in_seconds = optional(number)
    request_path        = optional(string, "/")
  }))
  validation { # keys
    condition     = var.health_probes == null ? true : !anytrue([for k, _ in var.health_probes : k == "default"])
    error_message = <<-EOF
    The key describing a health probe cannot be \"default\".
    EOF
  }
  validation { # name
    condition = var.health_probes == null ? true : length([for _, v in var.health_probes : v.name]) == length(
      distinct([for _, v in var.health_probes : v.name])
    )
    error_message = <<-EOF
    The `name` property has to be unique among all health probe definitions.
    EOF
  }
  validation { # name
    condition = var.health_probes == null ? true : !anytrue(
      [for _, v in var.health_probes : v.name == "default_vmseries_probe"]
    )
    error_message = <<-EOF
    The `name` property cannot be \"default_vmseries_probe\".
    EOF
  }
  validation { # protocol
    condition = var.health_probes == null ? true : alltrue(
      [for k, v in var.health_probes : contains(["Tcp", "Http", "Https"], v.protocol)]
    )
    error_message = <<-EOF
    The `protocol` property can be one of \"Tcp\", \"Http\", \"Https\".
    EOF
  }
  validation { # port
    condition = var.health_probes == null ? true : alltrue(
      [for k, v in var.health_probes : v.port != null if v.protocol == "Tcp"]
    )
    error_message = <<-EOF
    The `port` property is required when protocol is set to \"Tcp\".
    EOF
  }
  validation { # port
    condition = var.health_probes == null ? true : alltrue([for k, v in var.health_probes :
      v.port >= 1 && v.port <= 65535
      if v.port != null
    ])
    error_message = <<-EOF
    The `port` property has to be a valid TCP port.
    EOF
  }
  validation { # interval_in_seconds
    condition = var.health_probes == null ? true : alltrue([for k, v in var.health_probes :
      v.interval_in_seconds >= 5 && v.interval_in_seconds <= 3600
      if v.interval_in_seconds != null
    ])
    error_message = <<-EOF
    The `interval_in_seconds` property has to be between 5 and 3600 seconds (1 hour).
    EOF
  }
  validation { # probe_threshold
    condition = var.health_probes == null ? true : alltrue([for k, v in var.health_probes :
      v.probe_threshold >= 1 && v.probe_threshold <= 100
      if v.probe_threshold != null
    ])
    error_message = <<-EOF
    The `probe_threshold` property has to be between 1 and 100.
    EOF
  }
  validation { # request_path
    condition = var.health_probes == null ? true : alltrue(
      [for k, v in var.health_probes : v.request_path != null if v.protocol != "Tcp"]
    )
    error_message = <<-EOF
    The `request_path` property must be set if `protocol` is different than TCP.
    EOF
  }
}

variable "nsg_auto_rules_settings" {
  description = <<-EOF
  Controls automatic creation of NSG rules for all defined inbound rules.

  When skipped or assigned an explicit `null`, disables rules creation.

  Following properties are supported:

  - `nsg_name`                - (`string`, required) name of an existing Network Security Group
  - `nsg_resource_group_name  - (`string`, optional, defaults to Load Balancer's RG) name of a Resource Group hosting the NSG
  - `source_ips`              - (`list`, required) list of CIDRs/IP addresses from which access to the frontends will be allowed
  - `base_priority`           - (`nubmer`, optional, defaults to `1000`) minimum rule priority from which all
                                auto-generated rules grow, can take values between `100` and `4000`
  EOF
  default     = null
  type = object({
    nsg_name                = string
    nsg_resource_group_name = optional(string)
    source_ips              = list(string)
    base_priority           = optional(number, 1000)
  })
  validation { # source_ips
    condition = var.nsg_auto_rules_settings != null ? alltrue([
      for ip in var.nsg_auto_rules_settings.source_ips :
      can(regex("^(\\d{1,3}\\.){3}\\d{1,3}(\\/[12]?[0-9]|\\/3[0-2])?$", ip))
    ]) : true
    error_message = <<-EOF
    The `source_ips` property can an IPv4 address or address space in CIDR notation.
    EOF
  }
  validation { # base_priority
    condition = try(
      var.nsg_auto_rules_settings.base_priority >= 100 && var.nsg_auto_rules_settings.base_priority <= 4000,
      true
    )
    error_message = <<-EOF
    The `base_priority` property can take only values between `100` and `4000`.
    EOF
  }
}
