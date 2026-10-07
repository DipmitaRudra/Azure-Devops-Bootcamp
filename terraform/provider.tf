# Azure Provider source and version being used
terraform {
  required_version = ">=1.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.0.0"
    }
  }
  
# Configure remote backend for storing Terraform state in Azure Storage
backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstatebootcamp"
    container_name       = "tfstate"
    key                  = "azuredevopsbootcamp.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

