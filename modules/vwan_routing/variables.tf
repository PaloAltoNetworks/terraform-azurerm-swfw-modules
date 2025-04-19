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

