# Create a App Service Plan(ASP) within the resource group
resource "azurerm_service_plan" "asp_az_bootcamp" {
  name                = "asp-${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  os_type             = var.web_app_os
  sku_name            = var.web_app_sku_name
}

resource "azurerm_private_dns_zone" "priv_dns_zone_az_bootcamp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_zone_vnet_lnk_az_bootcamp" {
  name                = "pri-dns-zone-vnet-link-${var.project_name}"
  private_dns_zone_id = azurerm_private_dns_zone.priv_dns_zone_az_bootcamp.id
  virtual_network_id  = var.web_app_vnet_id
}

resource "azurerm_linux_web_app" "linux_web_app_az_bootcamp" {
  name                          = "linux-web-app-${var.project_name}"
  resource_group_name           = var.resource_group_name
  location                      = var.resource_group_location
  service_plan_id               = azurerm_service_plan.asp_az_bootcamp.id
  virtual_network_subnet_id     = var.web_app_vnet_integration_subnet_id
  public_network_access_enabled = false
  identity {
    type = var.webapp_identity_type
  }

  site_config {
    always_on = var.webapp_always_on

    application_stack {
      docker_image_name   = "${var.webapp_docker_image_name}:${var.webapp_docker_image_tag}"
      docker_registry_url = "https://${var.web_app_container_login_server}"

    }
    container_registry_use_managed_identity = var.acr_use_managed_identity
    ftps_state                              = var.webapp_ftps_state
    http2_enabled                           = var.webapp_http2_enable
    minimum_tls_version                     = var.webapp_minimum_tls_version
    websockets_enabled                      = var.webapp_websockets_enable
  }
}

resource "azurerm_private_endpoint" "priv_ep_web_app_az_bootcamp" {
  name                = "web-app-priv-ep-${var.project_name}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  subnet_id           = var.web_app_private_subnet_id

  private_service_connection {
    name                           = "web-app-priv-serv-con-${var.project_name}"
    private_connection_resource_id = azurerm_linux_web_app.linux_web_app_az_bootcamp.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "priv-dns-zone-group-${var.project_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.priv_dns_zone_az_bootcamp.id]
  }
}