# Palo Alto Networks Virtual Hub Routing Module for Azure

A Terraform module for managing routing in an Azure Virtual Hub.

## Usage

In order to use the `vhub_routing module`, you need to deploy the `vwan` module as a prerequisite.
Then you can use the example below to call the module and configure routing in the Virtual Hub:

```hcl
module "vhub_routing" {
  source = "PaloAltoNetworks/swfw-modules/azurerm//modules/vhub_routing"
  routing_intent = merge(var.virtual_hub_routing.routing_intent, {
    routing_policy = [
      for policy in var.virtual_hub_routing.routing_intent.routing_policy : merge(policy, {
        next_hop_id = module.cloudngfw[policy.next_hop_key].palo_alto_virtual_network_appliance_id
      })
    ]
  })
  virtual_hub_id = module.virtual_wan[var.virtual_hub_routing.virtual_wan_key].virtual_hub_ids[var.virtual_hub_routing.virtual_hub_key]
}
```

Below there are provided sample values for `virtual_hub_routing` map:

```hcl
virtual_hub_routing = {
  virtual_wan_key = "virtual_wan"
  virtual_hub_key = "virtual_hub"
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
