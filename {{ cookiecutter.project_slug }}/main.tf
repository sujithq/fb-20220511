terraform {
  backend "azurerm" {
  }
  required_version = "{{ cookiecutter.terraform_required_version }}"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "{{ cookiecutter.terraform_required_azurerm_version }}"
    }
  }
}

provider "azurerm" {
  features {}
}
