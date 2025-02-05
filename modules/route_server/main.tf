# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "this" {
  count = try(var.public_ip.create, false) ? 1 : 0

  resource_group_name = var.resource_group_name
  location            = var.region
  name                = var.public_ip.name

  allocation_method = "Static"
  sku               = "Standard"
  zones             = var.zones

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "this" {
  count = try(!var.public_ip.create && var.public_ip.name != null, false) ? 1 : 0

  name                = var.public_ip.name
  resource_group_name = coalesce(var.public_ip.resource_group_name, var.resource_group_name)
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_server
resource "azurerm_route_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = var.sku
  public_ip_address_id = coalesce(
    var.public_ip.id,
    try(azurerm_public_ip.this[0].id, data.azurerm_public_ip.this[0].id, null)
  )
  subnet_id                        = var.subnet_id
  branch_to_branch_traffic_enabled = var.branch_to_branch_traffic

  tags = var.tags
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_server_bgp_connection
resource "azurerm_route_server_bgp_connection" "this" {
  for_each = var.bgp_connections

  name            = each.value.name
  route_server_id = azurerm_route_server.this.id
  peer_asn        = each.value.peer_asn
  peer_ip         = each.value.peer_ip
}
