variable "project_name" {
  type        = string
  description = "Project name used for resource naming."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, test, prod)."
}

variable "azure_location" {
  type        = string
  description = "Azure location where resources will be deployed."
}

variable "vnet_address_space" {
  type        = list(string)
  description = "The address space for the Virtual Network."
}

variable "pub_sub_address_space" {
  type        = list(string)
  description = "The address spaces for the public subnets."
}

variable "priv_sub_address_space" {
  type        = list(string)
  description = "The address spaces for the private subnets."
}

variable "container_image_tag" {
  type        = string
  description = "Tag for the container image used in deployments."
  default     = "latest"
}
