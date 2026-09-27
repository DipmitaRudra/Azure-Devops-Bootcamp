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

variable "internet_address_space" {
  type        = list(string)
  description = "The address space for Internet traffic."
  default     = ["0.0.0.0/0"]
}

variable "vnet_address_space" {
  type        = list(string)
  description = "The address space assigned to the Azure virtual network."
}

variable "destination_port_range" {
  description = "List of ports to allow inbound on security group."
  type        = list(number)
  default     = [80]

}
variable "pub_sub_address_space" {
  type        = list(string)
  description = "List of public subnets address space."
}

variable "priv_sub_address_space" {
  description = "List of private subnet address space."
  type        = list(string)
}

variable "delegation_service_name" {
  description = "Service to which the subnet is delegated (e.g., Microsoft.Web/serverFarms)."
  type        = string
  default     = "Microsoft.Web/serverFarms"
}

variable "delegation_actions" {
  description = "List of actions allowed for the delegated service."
  type        = list(string)
  default     = ["Microsoft.Network/virtualNetworks/subnets/action"]
}
