output "az_acr_id_out" {
  description = "The ID of the Azure Container Registry."
  value       = azurerm_container_registry.acr_az_bootcamp.id
}

output "az_acr_name_out" {
  description = "The name of the Azure Container Registry."
  value       = azurerm_container_registry.acr_az_bootcamp.name
}

output "az_acr_login_server_out" {
  description = "The URL of the Azure Container Registry."
  value       = azurerm_container_registry.acr_az_bootcamp.login_server
}