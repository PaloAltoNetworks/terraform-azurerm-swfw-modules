variable "virtual_hub_ids" {
  description = "A map containing the IDs of the virtual hubs. Each entry associates a unique key with the corresponding virtual hub ID."
  type        = map(string)
}

variable "next_hops" {
  description = "A map of configurations for next hop resources. Each entry links a unique key to a specific next hop configuration, allowing for flexible routing setups."
  type        = map(string)
}

variable "route_table_ids" {
  description = "A map containing the IDs of route tables. Each entry maps a unique key to the corresponding route table ID used in routing configurations."
  type        = map(string)
}

variable "advanced_routing" {
  description = "Boolean flag indicating whether advanced routing using route tables will be utilized instead of routing intents. Set to true to enable advanced routing."
  type        = bool
  default     = false
}

variable "routing_intent" {
  description = <<-EOF
  An object defining the routing intent configuration.

  This includes the following attributes:

  - `routing_intent_name` - (`string`, required) The name of the routing intent. This must be unique across all defined routing intents.
  - `virtual_hub_key`     - (`string`, required) The key corresponding to the Virtual Hub associated with this routing intent.
  - `routing_policy`       - (`list`, required) A list of routing policies, each with the following attributes:
    - `routing_policy_name` - (`string`, required) The name of the routing policy. Must be unique within the routing intent.
    - `destinations`        - (`set`, required) A set of valid destination types, which can be either 'Internet' or 'PrivateTraffic'.
    - `next_hop_key`       - (`string`, required) The key for the next hop resource that this routing policy will utilize.

  EOF
  type = object({
    routing_intent_name = string
    virtual_hub_key     = string
    routing_policy = list(object({
      routing_policy_name = string
      destinations        = set(string)
      next_hop_key        = string
    }))
  })
}

variable "routes" {
  description = <<-EOF
  A list of routing configurations, where each entry defines a route with the following attributes:

  - `route_name`        - (`string`, required) The name of the route. Must be unique within the routing configurations.
  - `destinations_type` - (`string`, required) Specifies the type of destinations. Valid options include 'CIDR', 'ResourceId', or 'Service'.
  - `destinations`      - (`list`, required) A list of destinations for the route.
  - `next_hop_type`     - (`string`, required) Specifies the type of next hop, which defaults to 'ResourceId'.
  - `nex_hop_key`       - (`string`, required) The key for the next hop resource to which the route points.
  - `route_table_key`   - (`string`, required) The key of the route table to which this route belongs.

  EOF
  type = list(object({
    route_name        = string
    destinations_type = string
    destinations      = list(string)
    next_hop_type     = string
    nex_hop_key       = string
    route_table_key   = string
  }))
}


