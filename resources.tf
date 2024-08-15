terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
      configuration_aliases = [ azuread.auth_session ]
    }

    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [ azurerm.auth_session ]
    }

    databricks = {
      source  = "databricks/databricks"
      configuration_aliases = [ databricks.accounts ]
    }
  }
}


locals {
  databricks_metastore_grants = [{
    principal = "${var.databricks_group_prefix}-admin"
    privileges = var.databricks_metastore_grants
  }]

  databricks_catalog_grants = [{
    principal = "${var.databricks_group_prefix}-admin"
    privileges = var.databricks_catalog_grants
  }]
}


##---------------------------------------------------------------------------------------------------------------------
## AZURERM RESOURCE GROUP RESOURCE
##
## Create an Azure Resource Group to organize/group collections of resources, and isolate for billing.
##
## Parameters:
## - `name`: Azure Resource Group name.
## - `location`: Azure resource group location.
##---------------------------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  provider = azurerm.auth_session

  name     = var.azure_resource_group_name
  location = var.azure_region
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURERM DATABRICKS WORKSPACE RESOURCE
##
## This resource provisions an Azure Databricks workspace.
## 
## Parameters:
## - `name`: The name of the Databricks workspace.
## - `resource_group_name`: The name of the resource group where the Databricks workspace will be created.
## - `location`: The location/region where the Databricks workspace will be deployed.
## - `sku`: The SKU (stock-keeping unit) of the Databricks workspace.
## - `managed_resource_group_name`: The name of the managed resource group associated with the Databricks workspace.
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_databricks_workspace" "this" {
  provider                    = azurerm.auth_session
  name                        = var.databricks_workspace_name
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  sku                         = var.databricks_workspace_sku
  managed_resource_group_name = "${var.databricks_workspace_name}-resource-group"
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS WORKSPACE PROVIDER
##
## This Terraform configuration defines a Databricks provider block, which establishes a connection to an 
## Azure Databricks workspace.
## Authorization managed using Environment Variables:
##   - DATABRICKS_TOKEN
##  
## Parameters:
## - `auth_type`: Authentication override to stop from clashing with account provider.
## - `host`: Specifies the hostname of the Databricks workspace.
## ---------------------------------------------------------------------------------------------------------------------
provider "databricks" {
  alias     = "workspace"
  auth_type = "azure-client-secret"
  host      = "https://${azurerm_databricks_workspace.this.workspace_url}/"
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURERM CLIENT CONFIG DATA SOURCE
## 
## Azure Resource Management Client Configuration
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_client_config" "this" {
  provider = azurerm.auth_session
}


## ---------------------------------------------------------------------------------------------------------------------
## AZUREAD APPLICATION DATA SOURCE
## 
## Azure Active Diretory Application Configuration
##
## Parameters:
##  - `client_id`: Azure application client ID.
## ---------------------------------------------------------------------------------------------------------------------
data "azuread_application" "this" {
  provider   = azuread.auth_session
  depends_on = [ azurerm_databricks_workspace.this ]
  
  client_id = data.azurerm_client_config.this.client_id
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURE ACTIVE DIRECTORY APPLICATION PASSWORD RESOURCE
##
## This resource creates a secret for an Azure Active Directory service principal.
##
## Parameters:
## - `application_id`: The ID of the service principal for which the password is generated.
## - `end_date_relative`: The relative expiration date for the password.
## ---------------------------------------------------------------------------------------------------------------------
resource "azuread_application_password" "this" {
  provider   = azuread.auth_session

  application_id    = "/applications/${data.azuread_application.this.object_id}"
  end_date_relative = var.azure_databricks_client_secret_expiration
}


## ---------------------------------------------------------------------------------------------------------------------
## KEY_VAULT MODULE
##
## This module configures a key vault in Azure.
## 
## Parameters:
## - `key_vault_name`: The name of the key vault.
## - `resource_group_location`: The location of the resource group where the key vault will be created.
## - `resource_group_name`: The name of the resource group where the key vault will be created.
## - `security_group_id`: The ID of the security group associated with the key vault.
## ---------------------------------------------------------------------------------------------------------------------
module "key_vault" {
  source                  = "./modules/azure_key_vault"
  depends_on              = [ azurerm_resource_group.this ]

  key_vault_name          = var.azure_key_vault_name
  resource_group_location = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  security_group_id       = var.SECURITY_GROUP_ID

  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## KEY VAULT CLIENT ID SECRET MODULE
##
## This module creates a secret in an Azure Key Vault to store the client ID.
## 
## Parameters:
## - `key_vault_id`: The ID of the Azure Key Vault where the secret will be stored.
## - `key_vault_secret_name`: The name of the secret to be created in the Azure Key Vault.
## - `key_vault_secret_value`: The value of the secret (in this case, the client ID).
## ---------------------------------------------------------------------------------------------------------------------
module "key_vault_client_id" {
  source                  = "./modules/azure_key_vault_secret"
  depends_on              = [ module.key_vault ]
  
  key_vault_id           = module.key_vault.key_vault_id
  key_vault_secret_name  = var.azure_databricks_client_id_secret_name
  key_vault_secret_value = data.azurerm_client_config.this.client_id
  
  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## KEY VAULT CLIENT SECRET MODULE
##
## This module creates a secret in an Azure Key Vault to store the client secret.
## 
## Parameters:
## - `key_vault_id`: The ID of the Azure Key Vault where the secret will be stored.
## - `key_vault_secret_name`: The name of the secret to be created in the Azure Key Vault.
## - `key_vault_secret_value`: The value of the secret (in this case, the client secret).
## ---------------------------------------------------------------------------------------------------------------------
module "key_vault_client_secret" {
  source                  = "./modules/azure_key_vault_secret"
  depends_on              = [ module.key_vault ]
  
  key_vault_id           = module.key_vault.key_vault_id
  key_vault_secret_name  = var.azure_databricks_client_secret_secret_name
  key_vault_secret_value = azuread_application_password.this.value
  
  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS CURRENT USER DATA
##
## Retrieves information about the current Service Principal in Databricks. This will be the Databricks
## Accounts admin found in the Databricks CLI Profile.
## ---------------------------------------------------------------------------------------------------------------------
data "databricks_current_user" "this" {
  provider   = databricks.workspace
  depends_on = [ azurerm_databricks_workspace.this ]
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SERVICE PRINCIPAL ROLE RESOURCE
## 
## Append a Databricks Account role to an existing Databricks service principal.
## 
## Parameters:
## - `service_principal_id`: Databricks Accounts service principal client ID.
## - `role`: Databricks Accounts service principal role name.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_service_principal_role" "this" {
  provider   = databricks.accounts
  depends_on = [ azurerm_databricks_workspace.this ]
  
  service_principal_id = data.databricks_current_user.this.id
  role                 = "account_admin"
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SERVICE PRINCIPAL ROLE RESOURCE
## 
## Append a Databricks Account role to an existing Databricks service principal.
## 
## Parameters:
## - `service_principal_id`: Databricks Accounts service principal client ID.
## - `role`: Databricks Accounts service principal role name.
## ---------------------------------------------------------------------------------------------------------------------
data "databricks_user" "this" {
  provider   = databricks.accounts
  depends_on = [ databricks_service_principal_role.this ]
  
  user_name = var.DATABRICKS_ADMINISTRATOR
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS ADMIN GROUP MODULE
##
## This module creates a Databricks group with administrative privileges, and assigns both the Databricks Accounts
## admin & the Azure Service Principal to the admin group.
##
## Parameters:
## - `group_name`: The name of the Databricks group.
## - `allow_cluster_create`: Whether to allow creating clusters.
## - `allow_databricks_sql_access`: Whether to allow access to Databricks SQL.
## - `allow_instance_pool_create`: Whether to allow creating instance pools.
## - `member_ids`: List of Databricks member IDs to assign into the group.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_admin_group" {
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_group?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on = [ databricks_service_principal_role.this ]
  
  group_name                  = "${var.databricks_group_prefix}-admin"
  allow_cluster_create        = true
  allow_databricks_sql_access = true
  allow_instance_pool_create  = true
  member_ids                  = [
    data.databricks_current_user.this.id,
    data.databricks_user.this.id
  ]

  providers = {
    databricks.workspace = databricks.accounts
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS USER GROUP MODULE
##
## This module creates a Databricks group with user privileges.
##
## Parameters:
## - `group_name`: The name of the Databricks group.
## - `allow_databricks_sql_access`: Whether to allow access to Databricks SQL.
##
## Providers:
## - `databricks.workspace`: The Databricks provider for managing workspace resources.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_user_group" {
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_group?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on = [ databricks_service_principal_role.this ]
  
  group_name                  = "${var.databricks_group_prefix}-user"
  allow_databricks_sql_access = true

  providers = {
    databricks.workspace = databricks.accounts
  }
}


##---------------------------------------------------------------------------------------------------------------------
## DATABRICKS METASTORE MODULE
##
## This module creates an ADLS Storage Account as an external data source for Databricks Unity Catalog. 
## It depends on an existing Azure resource group and uses a security group ID provided by the 
## service account authentication module.
##
## Parameters:
## - `databricks_storage_name`: ADLS storage account name and Databricks Metastore Name.
## - `azure_container_name`: ADLS storage account container name.
## - `azure_resource_group`: Azure Resource Group name.
## - `security_group_id`: Azure AD Group ID to allow for access.
##---------------------------------------------------------------------------------------------------------------------
module "databricks_metastore" {
  source     = "./modules/azure_databricks_metastore"
  depends_on = [ module.databricks_admin_group ]

  azure_tenant_id               = data.azurerm_client_config.this.tenant_id
  azure_client_id               = data.azurerm_client_config.this.client_id
  azure_client_secret           = azuread_application_password.this.value
  azure_container_name          = "metastore"
  azure_resource_group          = azurerm_resource_group.this.name
  azure_security_group_id       = var.SECURITY_GROUP_ID
  databricks_storage_name       = "${var.databricks_workspace_name}-${azurerm_resource_group.this.location}"
  databricks_metastore_grants   = local.databricks_metastore_grants
  databricks_catalog_grants     = local.databricks_catalog_grants
  databricks_catalog_name       = var.databricks_catalog_name
  databricks_admin_group        = module.databricks_admin_group.databricks_group_name
  databricks_workspace_number   = azurerm_databricks_workspace.this.workspace_id

  providers = {
    azurerm.auth_session = azurerm.auth_session
    databricks.accounts = databricks.accounts
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SECRET SCOPE MODULE
## 
## This module creates a Databricks secret scope in an Azure Databricks workspace. We're unable to create a
## Databricks Secret Scope backed by Azure Key Vault due to the workspace provider requiring Azure specific
## authentication methods (Cannot be created using PAT).
## 
## Parameters:
## - `secret_scope`: Specifies the name of Databricks Secret Scope.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_secret_scope" {
  source   = "github.com/sim-parables/terraform-databricks//modules/databricks_secret_scope?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on   = [ azurerm_databricks_workspace.this ]

  secret_scope = var.databricks_secret_scope_name

  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SERVICE ACCOUNT KEY NAME SECRET MODULE
## 
## This module creates a secret in a Databricks secret scope. The secret stores the client ID 
## of an Azure service principal
## 
## Parameters:
## - `secret_scope_id`: Specifies the secret scope ID where the secret will be stored
## - `secret_name`: Specifies the name of the secret
## - `secret_data`: Specifies the data of the secret (client ID of the Azure service principal)
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_service_account_key_name_secret" {
  source      = "github.com/sim-parables/terraform-databricks//modules/databricks_secret?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on  = [ module.databricks_secret_scope ]
  
  secret_scope_id = module.databricks_secret_scope.databricks_secret_scope_id
  secret_name     = var.azure_databricks_client_id_secret_name
  secret_data     = data.azurerm_client_config.this.client_id
  
  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SERVICE ACCOUNT KEY SECRET MODULE
## 
## This module creates a secret in a Databricks secret scope. The secret stores the client Secret 
## of an Azure service principal
## 
## Parameters:
## - `secret_scope_id`: Specifies the secret scope ID where the secret will be stored
## - `secret_name`: Specifies the name of the secret
## - `secret_data`: Specifies the data of the secret (client Secret of the Azure service principal)
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_service_account_key_data_secret" {
  source       = "github.com/sim-parables/terraform-databricks//modules/databricks_secret?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on   = [ module.databricks_secret_scope ]
  
  secret_scope_id = module.databricks_secret_scope.databricks_secret_scope_id
  secret_name     = var.azure_databricks_client_secret_secret_name
  secret_data     = azuread_application_password.this.value

  providers = {
    databricks.workspace = databricks.workspace
  }
}