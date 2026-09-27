resource "azurerm_public_ip" "pub_ip_az_bootcamp" {
  name                = "pub-ip-${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  allocation_method   = "Static"
}