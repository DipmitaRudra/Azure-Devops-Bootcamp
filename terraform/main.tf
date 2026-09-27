
module "resource-group" {
  source                  = "./modules/resource_group"
  project_name            = var.project_name
  resource_group_location = var.azure_location

}



module "vnet" {
  source                  = "./modules/vnet"
  project_name            = var.project_name
  resource_group_name     = module.resource-group.az_rg_name_out
  resource_group_location = module.resource-group.az_rg_location_out
  vnet_address_space      = var.vnet_address_space
  pub_sub_address_space   = var.pub_sub_address_space
  priv_sub_address_space  = var.priv_sub_address_space
}

module "acr" {
  source                       = "./modules/container_registry"
  project_name                 = var.project_name
  resource_group_name          = module.resource-group.az_rg_name_out
  resource_group_location      = module.resource-group.az_rg_location_out
  webapp_identity_principal_id = module.web_app.az_webapp_identity_principal_id_out
}

module "web_app" {
  source                             = "./modules/web_app"
  project_name                       = var.project_name
  resource_group_name                = module.resource-group.az_rg_name_out
  resource_group_location            = module.resource-group.az_rg_location_out
  web_app_vnet_id                    = module.vnet.az_vnet_id_out
  web_app_private_subnet_id          = module.vnet.az_priv_sub_id_ep_out
  web_app_vnet_integration_subnet_id = module.vnet.az_priv_sub_id_vnet_intgr_out
  web_app_container_login_server     = module.acr.az_acr_login_server_out
  webapp_docker_image_tag            = var.container_image_tag
}

module "agw" {
  source                   = "./modules/application_gateway"
  project_name             = var.project_name
  resource_group_name      = module.resource-group.az_rg_name_out
  resource_group_location  = module.resource-group.az_rg_location_out
  public_ip_id             = module.vnet.az_public_ip_id_out
  agw_subnet_id            = module.vnet.az_pub_sub_id_out
  web_app_backend_priv_ip  = module.web_app.az_webapp_private_endpoint_ip_out
  web_app_backend_hostname = module.web_app.az_webapp_hostname_out
}

output "az_public_ip_show" {
  value = "http://${module.vnet.az_public_ip_out}"
}

output "az_public_ip_fqdn_show" {
  value = "http://${module.vnet.az_public_ip_fqdn_out}"
}
