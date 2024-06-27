terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [
        azurerm.auth_session,
      ]
    }
  }
}

locals {
  cloud   = "azure"
  program = "spark-databricks"
  project = "datasim"
}

locals  {
  tags    = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}

## ---------------------------------------------------------------------------------------------------------------------
## AZURE KEY VAULT SECRET RESOURCE
##
## This resource defines a secret in an Azure Key Vault.
## 
## Parameters:
## - `provider`: The Azure provider configuration.
## - `name`: The name of the secret.
## - `value`: The value of the secret.
## - `key_vault_id`: The ID of the Key Vault where the secret is stored.
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "this" {
  provider     = azurerm.auth_session
  name         = var.key_vault_secret_name
  value        = var.key_vault_secret_value
  key_vault_id = var.key_vault_id
  tags         = local.tags
}
