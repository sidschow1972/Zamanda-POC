terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stzamandatfstate"
    container_name       = "tfstate"
    key                  = "zammadpoc/infra.tfstate"
  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
    subscription_id = var.subscrbiption_id
}
