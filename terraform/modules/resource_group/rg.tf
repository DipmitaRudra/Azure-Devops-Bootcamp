
# Create a resource group
resource "azurerm_resource_group" "rg_az_bootcamp" {
  name     = "rg-${var.project_name}"
  location = var.resource_group_location
}
