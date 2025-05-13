variable "routing_intent" {
  description = <<-EOF
  Map of objects defining Routing Intent configurations for Virtual Hubs.

  Each object key represents a unique identifier, and the value supports the following attributes:

  - `virtual_hub_id` - (`string`, required) the resource ID of the Virtual Hub where the Routing Intent should be applied.

  - `routing_intent` - (`object`, required) configuration of the Routing Intent. Supports:
    - `routing_intent_name` - (`string`, required) the name of the Routing Intent. Must be unique across all defined intents.
    - `routing_policy`      - (`list`, required) a list of Routing Policies to apply. Each object supports:
      - `routing_policy_name` - (`string`, required) the name of the Routing Policy. Must be unique within the Routing Intent.
      - `destinations`        - (`list(string)`, required) list of traffic types the policy applies to. Valid values are: `Internet`, 
                                `PrivateTraffic`
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
}

variable "routes" {
  description = <<-EOF
  A map of routing configurations, where each entry defines a route with the following attributes:

  - `name`              - (`string`, required) the name of the route. Must be unique within the routing configurations.
  - `destinations_type` - (`string`, required) specifies the type of destinations. Valid options include 'CIDR', 'ResourceId', or 'Service'.
  - `destinations`      - (`list`, required) a list of destinations for the route.
  - `next_hop_type`     - (`string`, required) specifies the type of next hop, which defaults to 'ResourceId'.
  - `next_hop_id`       - (`string`, required) the id for the next hop resource to which the route points.
  - `route_table_id`   - (`string`, required) the id of the route table to which this route belongs.

  EOF
  type = map(object({
    name              = string
    destinations_type = string
    destinations      = list(string)
    next_hop_type     = optional(string, "ResourceId")
    next_hop_id       = string
    route_table_id    = string
  }))
  default = {}
}
