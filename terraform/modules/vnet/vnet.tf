# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet_az_bootcamp" {
  name                = "vnet-${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  address_space       = var.vnet_address_space
}

#Create subnets within the virtual network

##Create 2 public-subnets
resource "azurerm_subnet" "pub_subnet_az_bootcamp" {
  name                            = "pub-sub-${var.project_name}-${count.index + 1}"
  count                           = length(var.pub_sub_address_space)
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.vnet_az_bootcamp.name
  address_prefixes                = [var.pub_sub_address_space[count.index]]
  default_outbound_access_enabled = true

}

##Create 2 private-subnets for Application
resource "azurerm_subnet" "priv_subnet_az_bootcamp" {
  name                            = "priv-sub-${var.project_name}-${count.index + 1}"
  count                           = length(var.priv_sub_address_space)
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.vnet_az_bootcamp.name
  address_prefixes                = [var.priv_sub_address_space[count.index]]
  default_outbound_access_enabled = false



  dynamic "delegation" {
    for_each = count.index == 0 ? [1] : [] # only subnet[0] gets delegation
    content {
      name = "delg-priv-sub-${var.project_name}"

      service_delegation {
        name    = var.delegation_service_name
        actions = var.delegation_actions
      }
    }
  }
  private_endpoint_network_policies = count.index == 1 ? "Disabled" : "Enabled"
}

