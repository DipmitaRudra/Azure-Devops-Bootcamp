output "az_vnet_id_out" {
  description = "This represents the VNet ID for AGW."
  value       = azurerm_virtual_network.vnet_az_bootcamp.id
}

output "az_pub_sub_id_out" {
  description = "This represents the Public Subnet ID for AGW."
  value       = azurerm_subnet.pub_subnet_az_bootcamp[0].id
}

output "az_public_ip_out" {
  description = "This represents the Public IP ID for AGW."
  value       = azurerm_public_ip.pub_ip_az_bootcamp.id

}

output "az_priv_sub_id_ep_out" {
  description = "This represents the Private Subnet ID for Web App Private End Point ."
  value       = azurerm_subnet.priv_subnet_az_bootcamp[1].id
}

output "az_priv_sub_id_vnet_intgr_out" {
  description = "This represents the Private Subnet ID for Web App VNet integration."
  value       = azurerm_subnet.priv_subnet_az_bootcamp[0].id
}