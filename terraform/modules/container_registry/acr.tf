resource "azurerm_container_registry" "acr_az_bootcamp" {
  name                = "acr${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled
}

resource "azurerm_role_assignment" "acr_role_az_bootcamp" {
  scope                = azurerm_container_registry.acr_az_bootcamp.id
  role_definition_name = "AcrPull"
  principal_id         = var.webapp_identity_principal_id
}