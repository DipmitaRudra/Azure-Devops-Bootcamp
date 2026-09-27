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


variable "agw_subnet_id" {
  type        = string
  description = "The ID of the Application Gateway subnet."

}

variable "public_ip_id" {
  type        = string
  description = "The ID of the Public IP resource used by the Application Gateway."

}

variable "agw_sku_name" {
  type        = string
  description = "The SKU name for Application Gateway."
  default     = "Standard_v2"
}

variable "agw_sku_tier" {
  type        = string
  description = "The SKU Tier for Application Gateway."
  default     = "Standard_v2"
}


variable "agw_autoscale_min_capacity" {
  type        = number
  description = "The minimum autoscaling capacity for Application Gateway."
  default     = 0
}

variable "agw_autoscale_max_capacity" {
  type        = number
  description = "The maximum autoscaling capacity for Application Gateway."
  default     = 2
}

variable "agw_port" {
  description = "Port used by AGW for both frontend listener and backend pool."
  type        = number
  default     = 80

}

variable "agw_protocol" {
  description = "Protocol used by AGW to handle traffic."
  type        = string
  default     = "Http"
}

variable "agw_cookie_based_affinity" {
  description = "Whether AGW enables cookie-based session affinity (sticky sessions)."
  type        = string
  default     = "Disabled"
}

variable "agw_request_timeout" {
  description = "Maximum time in seconds AGW waits for a backend response before timing out."
  type        = number
  default     = 60
}


variable "agw_probe_path" {
  description = "Path checked by AGW health probe to verify backend availability."
  type        = string
  default     = "/"

}

variable "agw_probe_interval" {
  description = "Seconds between consecutive AGW health probe requests."
  type        = number
  default     = 30

}

variable "agw_probe_timeout" {
  description = "Seconds before an AGW probe request is considered failed."
  type        = number
  default     = 30

}

variable "agw_probe_unhealthy_threshold" {
  description = "Number of failed AGW probes before marking a backend unhealthy."
  type        = number
  default     = 3

}

variable "agw_route_rule_priority" {
  description = "Priority value for the AGW routing rule (lower numbers are evaluated first)."
  type        = number
  default     = 9

}

variable "agw_route_rule_type" {
  description = "Type of routing rule used by the AGW."
  type        = string
  default     = "Basic"

}

variable "web_app_backend_priv_ip" {
  description = "It represents the private IP of the Web App Private Endpoint."
  type        = string
}

variable "web_app_backend_hostname" {
  description = "It represents the Hostname of the Web App."
  type        = string
}