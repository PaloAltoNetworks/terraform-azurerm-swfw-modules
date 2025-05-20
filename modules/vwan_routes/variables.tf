variable "routing_intent" {
  description = <<-EOF
  Map of objects defining Routing Intent configuration for Virtual Hubs.

  Each object key represents a unique identifier, and the value supports the following attributes:

  - `virtual_hub_id` - (`string`, required) the resource ID of the Virtual Hub where the Routing Intent should be applied.
  - `routing_intent` - (`object`, required) configuration of the Routing Intent, following properties are available:
    - `routing_intent_name` - (`string`, required) the name of the Routing Intent, must be unique across all defined intents.
    - `routing_policy`      - (`list`, required) a list of Routing Policies to apply, following properties are available:
      - `routing_policy_name` - (`string`, required) the name of the Routing Policy, must be unique within the Routing Intent.
      - `destinations`        - (`list(string)`, required) list of traffic types the policy applies to, valid values are: 
                                `Internet`, `PrivateTraffic`.
      - `next_hop_id`         - (`string`, required) the resource ID of the next hop used by this routing policy.

  EOF
  default     = {}
  type = map(object({
    virtual_hub_id = string
    routing_intent = object({
      routing_intent_name = string
      routing_policy = list(object({
        routing_policy_name = string
        destinations        = list(string)
        next_hop_id         = string
      }))
    })
  }))
  validation { # routing_intent_name
    condition = alltrue([
      length([for _, intent in var.routing_intent : intent.routing_intent.routing_intent_name]) ==
      length(distinct([for _, intent in var.routing_intent : intent.routing_intent.routing_intent_name]))
    ])
    error_message = <<-EOF
    The `routing_intent_name` property of the routing intent must be unique.
    EOF
  }
}

variable "routes" {
  description = <<-EOF
  A map of routing configurations, where each entry defines a route with the following attributes:

  - `name`              - (`string`, required) the name of the route. Must be unique within the routing configurations.
  - `destinations_type` - (`string`, required) specifies the type of destinations, valid values are: `CIDR`, `ResourceId`,
                          or `Service`.
  - `destinations`      - (`list`, required) a list of destinations for the route.
  - `next_hop_type`     - (`string`, required, defaults to "ResourceId") specifies the type of next hop.
  - `next_hop_id`       - (`string`, required) the id for the next hop resource to which the route points.
  - `route_table_id`    - (`string`, required) the id of the route table to which this route belongs.

  EOF
  default     = {}
  type = map(object({
    name              = string
    destinations_type = string
    destinations      = list(string)
    next_hop_type     = optional(string, "ResourceId")
    next_hop_id       = string
    route_table_id    = string
  }))
  validation { # name
    condition = alltrue([
      length([for _, route in var.routes : route.name]) ==
      length(distinct([for _, route in var.routes : route.name]))
    ])
    error_message = <<-EOF
    The `name` property of the route must be unique.
    EOF
  }
  validation { # destinations_type
    condition = alltrue([
      for _, route in var.routes : [
        contains(["CIDR", "ResourceId", "Service"], route.destinations_type)
      ]
    ])
    error_message = <<-EOF
    The `destinations_type` property value must be of \"CIDR\", \"ResourceId\" or \"Service\".
    EOF
  }
  validation { # next_hop_type
    condition = alltrue([
      for _, route in var.routes : [
        contains(["ResourceId"], route.next_hop_type)
      ]
    ])
    error_message = <<-EOF
    The `next_hop_type` property value must be of \"ResourceId\".
    EOF
  }
}
