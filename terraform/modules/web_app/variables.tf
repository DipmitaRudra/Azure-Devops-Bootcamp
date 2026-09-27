variable "project_name" {
  type        = string
  description = "Project name used for resource naming/tagging."

}

variable "resource_group_name" {
  type        = string
  description = "The name of the Azure resource group."
}


variable "resource_group_location" {
  type        = string
  description = "The location of the Azure resource group."
}

variable "web_app_vnet_id" {
  description = "The VNet ID used for the Private DNS Zone link."
  type        = string
}

variable "web_app_os" {
  type        = string
  description = "The Operating System of the Web App."
  default     = "Linux"
}

variable "web_app_sku_name" {
  type        = string
  description = "The SKU name of the App Service Plan."
  default     = "B1"
}


variable "webapp_identity_type" {
  description = "Specifies the identity type for the Web App."
  type        = string
  default     = "SystemAssigned"
}

variable "webapp_always_on" {
  description = "Specifies if the Web App should always stay on."
  type        = bool
  default     = false
}

variable "web_app_container_login_server" {
  description = "The login server URL of the Azure Container Registry used by the Web App."
  type        = string
}

variable "webapp_docker_image_name" {
  description = "The Docker image repository name used by the Web App."
  type        = string
  default     = "azuredevopsbootcampapp"
}

variable "webapp_docker_image_tag" {
  type        = string
  description = "The tag of the Docker image used by the Web App. This will be replaced by the Git commit SHA in CI/CD for rollback support."
}

variable "acr_use_managed_identity" {
  type        = bool
  description = "Specifies whether the Web App should use its Managed Identity to authenticate to the container registry."
  default     = true
}

variable "webapp_ftps_state" {
  description = "FTPS/FTP state for the Web App."
  type        = string
  default     = "Disabled"
}

variable "webapp_http2_enable" {
  description = "Enable HTTP/2 protocol support for the Web App."
  type        = bool
  default     = true
}

variable "webapp_minimum_tls_version" {
  description = "Minimum TLS version required for HTTPS requests."
  type        = string
  default     = "1.2"
}

variable "webapp_websockets_enable" {
  description = "Enable WebSockets for real-time communication."
  type        = bool
  default     = false
}

variable "web_app_private_subnet_id" {
  description = "Private subnet ID used for Web App Private Endpoint."
  type        = string
}

variable "web_app_vnet_integration_subnet_id" {
  description = "Private subnet ID used for Web App VNet integration."
  type        = string
}




