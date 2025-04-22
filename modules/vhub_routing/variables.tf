variable "virtual_hub_id" {
  description = "The resource ID of the Azure Virtual Hub where routing or other configurations will be applied."
  type        = string
  default     = null
}

variable "routing_intent" {
  description = <<-EOF
  An object defining the routing intent configuration.

  This includes the following attributes:

  - `routing_intent_name` - (`string`, required) The name of the routing intent. This must be unique across all defined routing intents.
  - `routing_policy`       - (`list`, required) A list of routing policies, each with the following attributes:
    - `routing_policy_name` - (`string`, required) The name of the routing policy. Must be unique within the routing intent.
    - `destinations`        - (`set`, required) A set of valid destination types, which can be either 'Internet' or 'PrivateTraffic'.
    - `next_hop_id`       - (`string`, required) The ID for the next hop resource that this routing policy will utilize.

  EOF
  default     = null
  type = object({
    routing_intent_name = string
    routing_policy = list(object({
      routing_policy_name = string
      destinations        = set(string)
      next_hop_id         = string
    }))
  })
}

variable "route_table_id" {
  description = "!!!!A map containing the IDs of route tables. Each entry maps a unique key to the corresponding route table ID used in routing configurations."
  type        = string
  default     = null
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
    next_hop_id       = string
    #route_table_key   = string
  }))
  default = []
}
