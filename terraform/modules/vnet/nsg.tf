# Create a Network Security Group(NSG) within the resource group(for AGW)
resource "azurerm_network_security_group" "nsg_agw_az_bootcamp" {
  name                = "nsg-agw-${var.project_name}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  #Create Inbound Security Rules for AGW-NSG
  security_rule {
    name                       = "inbound-http-agw-${var.project_name}"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.destination_port_range[0]
    source_address_prefix      = var.internet_address_space[0]
    destination_address_prefix = "*"
  }

  # Allow Azure GatewayManager infrastructure traffic required for Application Gateway v2
  security_rule {
    name                       = "allow-agw-${var.project_name}"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
    destination_port_range     = "65200-65535"
  }

}

#Create association between Inbound AGW-NSG and pub-sub-1
resource "azurerm_subnet_network_security_group_association" "agw_az_bootcamp" {
  subnet_id                 = azurerm_subnet.pub_subnet_az_bootcamp[0].id
  network_security_group_id = azurerm_network_security_group.nsg_agw_az_bootcamp.id

}

# Create a Network Security Group(NSG) within the resource group(for Web App)
resource "azurerm_network_security_group" "nsg_app_az_bootcamp" {
  name                = "nsg-app-${var.project_name}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  #Create Inbound Security Rules for App-NSG
  security_rule {
    name                       = "inbound-http-app-${var.project_name}"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.destination_port_range[0]
    source_address_prefix      = var.pub_sub_address_space[0]
    destination_address_prefix = "*"
  }

}

#Create association between Inbound App-NSG and both priv-sub
resource "azurerm_subnet_network_security_group_association" "app_az_bootcamp" {
  count                     = length(var.priv_sub_address_space)
  subnet_id                 = azurerm_subnet.priv_subnet_az_bootcamp[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg_app_az_bootcamp.id

}

