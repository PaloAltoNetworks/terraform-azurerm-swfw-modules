# Palo Alto Networks Virtual HUB Routing Module for Azure

A Terraform module for managing routing in an Azure Virtual HUB.

## Usage

In order to use the `vhub_routing` module, you need to deploy the `vwan` and `vhub` module as a prerequisite.
Then you can use the example below to call the module and configure routing in the Virtual Hub:

```hcl
module "vhub_routing" {
  source = "../../modules/vhub_routing"

  for_each = var.virtual_wan.virtual_hubs

  routing_intent = merge(each.value.routing_intent, {
    routing_policy = [
      for policy in each.value.routing_intent.routing_policy : merge(policy, {
        next_hop_id = module.cloudngfw[policy.next_hop_key].palo_alto_virtual_network_appliance_id
      })
    ]
  })
  virtual_hub_id = module.virtual_hub[each.key].virtual_hub_id
}
```

Below there are provided sample values for `virtual_hub_routing` map:

```hcl
virtual_hub_routing = {
  routing_intent = {
    routing_intent_name = "routing_intent"
    routing_policy = [
      {
        routing_policy_name = "PrivateTraffic"
        destinations        = ["PrivateTraffic"]
        next_hop_key        = "cloudngfw"
      },
      {
        routing_policy_name = "Internet"
        destinations        = ["Internet"]
        next_hop_key        = "cloudngfw"
      }
    ]
  }
}
```

## Reference

### Requirements

- `terraform`, version: >= 1.5, < 2.0
- `azurerm`, version: ~> 4.0

### Providers

- `azurerm`, version: ~> 4.0



### Resources

- `virtual_hub_routing_intent` (managed)

### Required Inputs

Name | Type | Description
--- | --- | ---

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`virtual_hub_id`](#virtual_hub_id) | `string` | The resource ID of the Azure Virtual Hub where routing or other configurations will be applied.
[`routing_intent`](#routing_intent) | `object` | An object defining the routing intent configuration.
[`route_table_id`](#route_table_id) | `string` | !!!!A map containing the IDs of route tables.
[`routes`](#routes) | `list` | A list of routing configurations, where each entry defines a route with the following attributes:

- `route_name`        - (`string`, required) The name of the route.



### Required Inputs details

### Optional Inputs details

#### virtual_hub_id

The resource ID of the Azure Virtual Hub where routing or other configurations will be applied.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### routing_intent

An object defining the routing intent configuration.

This includes the following attributes:

- `routing_intent_name` - (`string`, required) The name of the routing intent. This must be unique across all defined routing intents.
- `routing_policy`       - (`list`, required) A list of routing policies, each with the following attributes:
  - `routing_policy_name` - (`string`, required) The name of the routing policy. Must be unique within the routing intent.
  - `destinations`        - (`set`, required) A set of valid destination types, which can be either 'Internet' or 'PrivateTraffic'.
  - `next_hop_id`       - (`string`, required) The ID for the next hop resource that this routing policy will utilize.



Type: 

```hcl
object({
    routing_intent_name = string
    routing_policy = list(object({
      routing_policy_name = string
      destinations        = set(string)
      next_hop_id         = string
    }))
  })
```


Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### route_table_id

!!!!A map containing the IDs of route tables. Each entry maps a unique key to the corresponding route table ID used in routing configurations.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### routes

A list of routing configurations, where each entry defines a route with the following attributes:

- `route_name`        - (`string`, required) The name of the route. Must be unique within the routing configurations.
- `destinations_type` - (`string`, required) Specifies the type of destinations. Valid options include 'CIDR', 'ResourceId', or 'Service'.
- `destinations`      - (`list`, required) A list of destinations for the route.
- `next_hop_type`     - (`string`, required) Specifies the type of next hop, which defaults to 'ResourceId'.
- `nex_hop_key`       - (`string`, required) The key for the next hop resource to which the route points.
- `route_table_key`   - (`string`, required) The key of the route table to which this route belongs.



Type: 

```hcl
list(object({
    route_name        = string
    destinations_type = string
    destinations      = list(string)
    next_hop_type     = string
    next_hop_id       = string
    #route_table_key   = string
  }))
```


Default value: `[]`

<sup>[back to list](#modules-optional-inputs)</sup>
