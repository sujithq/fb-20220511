terraform {
  backend "azurerm" {
  }
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azuread_service_principal" "MicrosoftWebApp" {
  application_id = "abfa0a7c-a6b6-4736-8310-5855508787cd"
}

data "azurerm_client_config" "current" {}

resource "random_string" "random" {
  length           = 3
  special          = false
  lower = true
}

resource "azurerm_resource_group" "this" {
  name     = "rg-fb-20220511"
  location = "westeurope"
}

resource "azurerm_key_vault" "this" {
  name                = "kvfb20220511${random_string.random.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
}

resource "azurerm_key_vault_access_policy" "MicrosoftWebApp" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.MicrosoftWebApp.object_id

  certificate_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "Get",
    "List",
    "Update",
    "Create",
    "Import",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "ManageContacts",
    "ManageIssuers",
    "DeleteIssuers",
    "GetIssuers",
    "ListIssuers",
    "SetIssuers",
    "Purge",
  ]

  key_permissions = [
    "Get",
    "List",
    "Update",
    "Backup",
    "Create",
    "Import",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "WrapKey",
    "Verify",
    # "Rotate",
    # "GetRotationPolicy",
    # "SetRotationPolicy",
  ]

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
  ]
}

resource "azurerm_key_vault_certificate" "this" {
  name         = "generated-cert"
  key_vault_id = azurerm_key_vault.this.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        # days_before_expiry = 30
        lifetime_percentage = 1
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["internal.contoso.com", "domain.hello.world"]
      }

      subject            = "CN=hello-world"
      validity_in_months = 1
    }
  }
}


data "azurerm_key_vault_certificate" "this" {
  name         = azurerm_key_vault_certificate.this.name
  key_vault_id = azurerm_key_vault.this.id
}


resource "azurerm_service_plan" "this" {
  name                = "plan-fb-20220511"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_web_app" "this" {
  name                = "app-fb-20220511-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_service_plan.this.location
  service_plan_id     = azurerm_service_plan.this.id

  site_config {}
}

resource "azurerm_app_service_certificate" "this" {
  name                = "app-cert-fb-20220511"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  # pfx_blob            = azurerm_key_vault_certificate.this.certificate_data_base64
  key_vault_secret_id = data.azurerm_key_vault_certificate.this.secret_id
  # password            = "terraform"
  depends_on = [azurerm_key_vault_access_policy.MicrosoftWebApp]
}