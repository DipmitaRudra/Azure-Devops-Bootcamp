##Create Route table for Public Subnet (Subnet-->Internet)
resource "azurerm_route_table" "rt_pub_sub_az_bootcamp" {
  name                = "rt-pub-sub-${var.project_name}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  route {
    name           = "route-outbound-pub-sub-${var.project_name}"
    address_prefix = var.internet_address_space[0]
    next_hop_type  = "Internet"
  }

}

resource "azurerm_subnet_route_table_association" "rt_pub_sub_assoc_az_bootcamp" {
  subnet_id      = azurerm_subnet.pub_subnet_az_bootcamp[0].id
  route_table_id = azurerm_route_table.rt_pub_sub_az_bootcamp.id
}


##Create Route table for Private Subnet (Private Subnets → Private Route Table)
resource "azurerm_route_table" "rt_priv_sub_az_bootcamp" {
  name                = "rt-priv-sub-${var.project_name}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_route_table_association" "rt_priv_sub_assoc_az_bootcamp" {
  count          = length(var.priv_sub_address_space)
  subnet_id      = azurerm_subnet.priv_subnet_az_bootcamp[count.index].id
  route_table_id = azurerm_route_table.rt_priv_sub_az_bootcamp.id
}

