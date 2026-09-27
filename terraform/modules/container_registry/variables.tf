variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Azure resource group."
}

variable "resource_group_location" {
  type        = string
  description = "The location of the Azure resource group."
}

variable "acr_sku" {
  type        = string
  description = "The SKU of the Azure Container Registry (Basic, Standard, Premium)."
  default     = "Basic"
}

variable "acr_admin_enabled" {
  type        = bool
  description = "Specifies whether the admin user is enabled for the ACR."
  default     = false
}

variable "webapp_identity_principal_id" {
  type        = string
  description = "The principal ID of the System Assigned Managed Identity for the Web App."
}