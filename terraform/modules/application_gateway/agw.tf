# Create a Application Gateway(AGW) within the resource group
resource "azurerm_application_gateway" "agw_az_bootcamp" {
  name                = "agw-${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location

  sku {
    name = var.agw_sku_name
    tier = var.agw_sku_tier
  }
  autoscale_configuration {
    min_capacity = var.agw_autoscale_min_capacity
    max_capacity = var.agw_autoscale_max_capacity
  }

  gateway_ip_configuration {
    name      = "agw-subnet-id-${var.project_name}"
    subnet_id = var.agw_subnet_id
  }

  frontend_port {
    name = "agw-port-${var.project_name}"
    port = var.agw_port
  }

  frontend_ip_configuration {
    name                 = "agw-ip-${var.project_name}"
    public_ip_address_id = var.public_ip_id
  }

  backend_address_pool {
    name         = "agw-beap-${var.project_name}"
    ip_addresses = [var.web_app_backend_priv_ip]
  }

  backend_http_settings {
    name                  = "agw-be-settings-${var.project_name}"
    cookie_based_affinity = var.agw_cookie_based_affinity
    port                  = var.agw_port
    protocol              = var.agw_protocol
    request_timeout       = var.agw_request_timeout
    probe_name            = "agw-probe-${var.project_name}"
    host_name             = var.web_app_backend_hostname
  }

  http_listener {
    name                           = "agw-listener-${var.project_name}"
    frontend_ip_configuration_name = "agw-ip-${var.project_name}"
    frontend_port_name             = "agw-port-${var.project_name}"
    protocol                       = var.agw_protocol
  }

  probe {
    name                                      = "agw-probe-${var.project_name}"
    protocol                                  = var.agw_protocol
    path                                      = var.agw_probe_path
    interval                                  = var.agw_probe_interval
    timeout                                   = var.agw_probe_timeout
    unhealthy_threshold                       = var.agw_probe_unhealthy_threshold
    pick_host_name_from_backend_http_settings = true
  }

  request_routing_rule {
    name                       = "agw-route-rules-${var.project_name}"
    priority                   = var.agw_route_rule_priority
    rule_type                  = var.agw_route_rule_type
    http_listener_name         = "agw-listener-${var.project_name}"
    backend_address_pool_name  = "agw-beap-${var.project_name}"
    backend_http_settings_name = "agw-be-settings-${var.project_name}"
  }
}