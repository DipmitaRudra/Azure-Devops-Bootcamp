output "az_rg_name_out" {
  description = "This represents the resource group name."
  value       = azurerm_resource_group.rg_az_bootcamp.name
}

output "az_rg_location_out" {
  description = "This represents the resource group location."
  value       = azurerm_resource_group.rg_az_bootcamp.location
}