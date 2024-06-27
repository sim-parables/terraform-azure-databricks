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
  key_vault_permisions = distinct(concat(var.key_vault_permissions,
    [
      "List",
      "Get",
      "Set",
      "Delete",
      "Purge"
    ]
  ))
  
  tags = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}

## ---------------------------------------------------------------------------------------------------------------------
## AZURE CLIENT CONFIGURATION DATA
##
## This data source retrieves the current Azure client configuration.
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_client_config" "current" {
  provider = azurerm.auth_session
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURE KEY VAULT RESOURCE
##
## This resource defines an Azure Key Vault.
## 
## Parameters:
## - `provider`: The Azure provider configuration.
## - `name`: The name of the Key Vault.
## - `location`: The location of the Key Vault.
## - `resource_group_name`: The name of the resource group in which to create the Key Vault.
## - `tenant_id`: The tenant ID associated with the Azure client configuration.
## - `sku_name`: The SKU name for the Key Vault.
## - `soft_delete_retention_days`: The number of days that items should be retained for during a soft delete.
## - `access_policy`: The access policy defining permissions for accessing secrets in the Key Vault.
##   - `tenant_id`: The tenant ID associated with the Azure client configuration.
##   - `object_id`: The object ID associated with the Azure client configuration.
##   - `secret_permissions`: The list of secret permissions granted to the client configuration.
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_key_vault" "this" {
  provider                   = azurerm.auth_session
  name                       = substr(var.key_vault_name, 0, 24)
  location                   = var.resource_group_location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku
  soft_delete_retention_days = var.key_vault_soft_retention_days
  tags                       = local.tags

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = local.key_vault_permisions
  }

  lifecycle {
    ignore_changes = all
  }

  timeouts {
    delete = "1m"
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURE KEY VAULT ACCESS POLICY RESOURCE
##
## This resource defines an access policy for an Azure Key Vault.
## 
## Parameters:
## - `provider`: The Azure provider configuration.
## - `key_vault_id`: The ID of the Key Vault to which the access policy applies.
## - `tenant_id`: The tenant ID associated with the Azure client configuration.
## - `object_id`: The object ID of the security group to which permissions are granted.
## - `secret_permissions`: The list of secret permissions granted to the security group.
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "this" {
  provider           = azurerm.auth_session
  key_vault_id       = azurerm_key_vault.this.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = var.security_group_id
  secret_permissions = local.key_vault_permisions
}
