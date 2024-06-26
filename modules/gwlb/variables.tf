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
  Controls zones for Gateway Load Balancer's Fronted IP configurations.

  Setting this variable to explicit `null` disables a zonal deployment.
  This can be helpful in regions where Availability Zones are not available.
  EOF
  default     = ["1", "2", "3"]
  nullable    = false
  type        = list(string)
}

variable "frontend_ip" {
  description = <<-EOF
  Frontend IP configuration of the Gateway Load Balancer.

  Following settings are available:
  - `name`                          - (`string`, required) name of the frontend IP configuration. `var.name` by default.
  - `subnet_id`                     - (`string`, required) id of a subnet to associate with the configuration.
  - `private_ip_address`            - (`string`, optional) private IP address to assign.
  - `private_ip_address_version`    - (`string`, optional, defaults to `IPv4`) the IP version for the private IP address. Can be
                                      one of "IPv4", "IPv6".
  EOF
  nullable    = false
  type = object({
    name                       = string
    subnet_id                  = string
    private_ip_address         = optional(string)
    private_ip_address_version = optional(string, "IPv4")
  })
  validation { # private_ip_address
    condition = (var.frontend_ip.private_ip_address != null ?
    can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.frontend_ip.private_ip_address)) : true)
    error_message = <<-EOF
    The `private_ip_address` property should be in IPv4 format.
    EOF
  }
  validation { # private_ip_address_version
    condition     = contains(["IPv4", "IPv6"], var.frontend_ip.private_ip_address_version)
    error_message = <<-EOF
    The `private_ip_address_version` property can be one of \"IPv4\", \"IPv6\".
    EOF
  }
}

variable "health_probe" {
  description = <<-EOF
  Health probe configuration for the Gateway Load Balancer backends.

  Following settings are available:
  - `name`                - (`string`, required) name of the health probe.
  - `protocol`            - (`string`, required) protocol used by the health probe, can be one of "Tcp", "Http" or "Https".
  - `port`                - (`number`, optional) port to run the probe against.
  - `probe_threshold`     - (`number`, optional) number of consecutive probes that decide on forwarding traffic to an endpoint.
  - `interval_in_seconds` - (`number`, optional) interval in seconds between probes, with a minimal value of 5.
  - `request_path`        - (`string`, optional) used only for non `Tcp` probes, the URI used to check the endpoint status when
                            `protocol` is set to `Http(s)`.
  EOF
  default = {
    name     = "health_probe"
    port     = 80
    protocol = "Tcp"
  }
  nullable = false
  type = object({
    name                = string
    protocol            = string
    port                = optional(number)
    probe_threshold     = optional(number)
    interval_in_seconds = optional(number)
    request_path        = optional(string, "/")
  })
  validation { # protocol
    condition     = contains(["Tcp", "Http", "Https"], var.health_probe.protocol)
    error_message = <<-EOF
    The `protocol` property can be one of \"Tcp\", \"Http\", \"Https\".
    EOF
  }
  validation { # port
    condition     = var.health_probe.protocol == "Tcp" ? var.health_probe.port != null : true
    error_message = <<-EOF
    The `port` property is required when protocol is set to \"Tcp\".
    EOF
  }
  validation { # port
    condition     = var.health_probe.port != null ? var.health_probe.port >= 1 && var.health_probe.port <= 65535 : true
    error_message = <<-EOF
    The `port` property has to be a valid TCP port.
    EOF
  }
  validation { # probe_threshold
    condition = (var.health_probe.probe_threshold != null ?
    var.health_probe.probe_threshold >= 1 && var.health_probe.probe_threshold <= 100 : true)
    error_message = <<-EOF
    The `probe_threshold` property has to be between 1 and 100.
    EOF
  }
  validation { # interval_in_seconds
    condition = (var.health_probe.interval_in_seconds != null ?
    var.health_probe.interval_in_seconds >= 5 && var.health_probe.interval_in_seconds <= 3600 : true)
    error_message = <<-EOF
    The `interval_in_seconds` property has to be between 5 and 3600 seconds (1 hour).
    EOF
  }
  validation { # request_path
    condition     = var.health_probe.protocol != "Tcp" ? var.health_probe.request_path != null : true
    error_message = <<-EOF
    The `request_path` property is required when protocol is set to \"Http\" or \"Https\".
    EOF
  }
}

variable "backends" {
  description = <<-EOF
  Map with backend configurations for the Gateway Load Balancer. Azure GWLB rule can have up to two backends.

  Following settings are available:
  - `name`              - (`string`, required) name of the backend.
  - `tunnel_interfaces` - (`map`, required) map with tunnel interfaces:
    - `identifier`        - (`number`, required) interface identifier.
    - `port`              - (`number`, required) interface port.
    - `type`              - (`string`, required) either "External" or "Internal".

  **Note!** \
  If one backend is specified, it has to have both external and internal tunnel interfaces specified.
  For two backends, each has to have exactly one.

  On GWLB inspection enabled VM-Series instance, `identifier` and `port` default to:
  - `800`/`2000` for `Internal` tunnel type
  - `801`/`2001` for `External` tunnel type

  Variable default reflects this configuration on GWLB side.
  Additionally, for VM-Series tunnel interface protocol is always VXLAN.
  EOF
  default = {
    backend = {
      name = "backend"
      tunnel_interfaces = {
        internal = {
          identifier = 800
          port       = 2000
          protocol   = "VXLAN"
          type       = "Internal"
        }
        external = {
          identifier = 801
          port       = 2001
          protocol   = "VXLAN"
          type       = "External"
        }
      }
    }
  }
  nullable = false
  type = map(object({
    name = string
    tunnel_interfaces = map(object({
      identifier = number
      port       = number
      protocol   = optional(string, "VXLAN")
      type       = string
    }))
  }))
  validation { # backends
    condition     = (var.backends == null ? true : length(var.backends) <= 2)
    error_message = <<-EOF
    Maximum allowed number of `backends` is 2.
    EOF
  }
  validation { # protocol
    condition = (var.backends == null ?
      true : alltrue(flatten([for k, v in var.backends :
    [for p, r in v.tunnel_interfaces : contains(["VXLAN"], r.protocol)]])))
    error_message = <<-EOF
    The `protocol` property can be only \"VXLAN\".
    EOF
  }
  validation { # type
    condition = (var.backends == null ?
      true : alltrue(flatten([for k, v in var.backends :
    [for p, r in v.tunnel_interfaces : contains(["Internal", "External"], r.type)]])))
    error_message = <<-EOF
    The `type` property can be one of \"Internal\", \"External\".
    EOF
  }
}

variable "lb_rule" {
  description = <<-EOF
  Load balancing rule configuration.

  Available options:
  - `name`              - (`string`, optional) name for the rule.
  - `load_distribution` - (`string`, optional, defaults to `Default`) specifies the load balancing distribution type to be used
                          by the Gateway Load Balancer. Can be one of "Default", "SourceIP", "SourceIPProtocol".
  EOF
  default = {
    name = "lb_rule"
  }
  nullable = false
  type = object({
    name              = string
    load_distribution = optional(string, "Default")
  })
  validation { # load_distribution
    condition     = contains(["Default", "SourceIP", "SourceIPProtocol"], var.lb_rule.load_distribution)
    error_message = <<-EOF
    The `load_distribution` property can be one of \"Default\", \"SourceIP\", \"SourceIPProtocol\".
    EOF
  }
}
