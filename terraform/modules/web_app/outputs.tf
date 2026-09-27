output "az_webapp_id_out" {
  description = "The resource ID of the Linux Web App."
  value       = azurerm_linux_web_app.linux_web_app_az_bootcamp.id
}

output "az_webapp_hostname_out" {
  description = "The default hostname (FQDN) of the Linux Web App."
  value       = azurerm_linux_web_app.linux_web_app_az_bootcamp.default_hostname
}

output "az_webapp_private_endpoint_id_out" {
  description = "The resource ID of the Private Endpoint for the Web App."
  value       = azurerm_private_endpoint.priv_ep_web_app_az_bootcamp.id
}

output "az_webapp_private_endpoint_ip_out" {
  description = "The private IP address allocated to the Web App's Private Endpoint."
  value       = azurerm_private_endpoint.priv_ep_web_app_az_bootcamp.private_service_connection[0].private_ip_address
}

output "az_webapp_identity_principal_id_out" {
  description = "The principal ID of the System Assigned Managed Identity for the Web App."
  value       = azurerm_linux_web_app.linux_web_app_az_bootcamp.identity[0].principal_id
}