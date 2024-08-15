<p float="left">
  <img id="b-0" src="https://img.shields.io/badge/Project%20Stage-Experimental-yellow.svg" height="25px"/>
  <img id="b-1" src="https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white" height="25px"/>
  <img id="b-2" src="https://img.shields.io/badge/Microsoft_Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white" height="25px"/>
</p>

# Terraform Azure Databricks Workspace & Unity Catalog Module

A reusable module for creating & configuring Databricks Workspaces with Unity Catalog on Azure.

> [!CAUTION]
> These terraform modules and CI/CD Workflow Actions are still experimental due to Azure & Databricks
> APIs still facing unstable tear downs, and Databricks CLI clashes when testing DAB runs. 
> Therefore, no E2E Integration Test is available until more observable stabilbilty is seen during 
> development in these areas. Dispatch Workflow Actions may be used while monitoring.

## Usage

```hcl
## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS Accounts PROVIDER
##
## This section defines the Databricks Accounts Provider with an alias for managing accounts.
## Authorization managed using Environment Variables
##   - DATABRICKS_HOST
##   - DATABRICKS_TOKEN
##
## Parameters:
## - `alias`: Alias for the provider.
## ---------------------------------------------------------------------------------------------------------------------
provider "databricks" {
  alias     = "accounts"
  auth_type = "oauth-m2m"
  profile   = var.DATABRICKS_CLI_PROFILE
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURE DATABRICKS WORKSPACE Module
##
## This module provisions a Databricks workspace in Azure.
## 
## Parameters:
## - `name`: The name of the Databricks workspace.
## - `azure_resource_group_name`: The name of the resource group where the Databricks workspace will be created.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_workspace" {
  source = "../../"

  DATABRICKS_ADMINISTRATOR     = var.DATABRICKS_ADMINISTRATOR
  SECURITY_GROUP_ID            = var.SECURITY_GROUP_ID
  databricks_workspace_name    = "${local.prefix}-workspace"
  databricks_workspace_sku     = "premium"
  azure_resource_group_name    = "${local.prefix}-resource-group"
  azure_region                 = var.azure_region
  azure_key_vault_name         = "${local.prefix}-key-vault"
  databricks_group_prefix      = "${local.prefix}-db-group"
  databricks_catalog_name      = "${local.prefix}-metastore"
  databricks_metastore_grants  = local.metastore_grants
  databricks_catalog_grants    = local.catalog_grants
  databricks_secret_scope_name = local.secret_scope
  tags                         = var.tags

  providers = {
    azuread.auth_session = azuread.auth_session
    azurerm.auth_session = azurerm.auth_session
    databricks.accounts = databricks.accounts
  }
}

```

## Inputs

| Name                         | Description                           | Type           | Required |
|:-----------------------------|:--------------------------------------|:---------------|:---------|
| DATABRICKS_ADMINISTRATOR     | DB Accounts & Workspace Admin email   | String         | Yes      |
| SECURITY_GROUP_ID            | Priviledged AD Group ID               | String         | Yes      |
| databricks_workspace_name    | DB Workspace Name                     | String         | Yes      |
| databricks_workspace_sku     | DB Workspace Sku                      | String         | No       |
| azure_resource_group_name    | Azure RG Name to Create               | String         | Yes      |
| azure_region                 | Azure Region                          | String         | Yes      |
| azure_key_vault_name         | Azure Key Vault Name to Create        | String         | No       |
| databricks_group_prefix      | DB Accounts & Workspace Group prefix  | String         | No       |
| databricks_catalog_name      | DB Unity Catalog Name                 | String         | No       |
| databricks_metastore_grants  | DB Unity Catalog Metastore Grants     | List(String)   | No       |
| databricks_catalog_grants    | DB UC Catalog Grants                  | List(String)   | No       |
| databricks_secret_scope_name | DB Secret Scope Name                  | String         | No       |


## Outputs

| Name                                     | Description                                   |
|:-----------------------------------------|:----------------------------------------------|
| databricks_host                          | Databricks (DB) Workspace URL                 |
| databricks_workspace_id                  | DB Workspace ID                               |
| databricks_workspace_number              | DB Workspace Unique Number                    |
| databricks_workspace_name                | DB Workspace Name                             |
| databricks_secret_scope_name             | DB Workspace Secret Scope Name                |
| databricks_secret_scope_id               | DB Workspace Secret Scope ID                  |
| databricks_secret_client_id_name         | DB Workspace Secret Name for SP Client ID     |
| databricks_secret_client_secret_name     | DB Workspace Secret Name for SP Client Secret |
| databricks_external_location_url         | DB Unity Catalog External Location ABFSS URL  |
| azure_keyvault_name                      | Azure Key Vault Name (AKV)                    |
| azure_keyvault_secret_client_id_name     | AKV Secret Name for SP Client ID              |
| azure_keyvault_secret_client_secret_name | AKV Secret Name for SP Client Secret          |
| databricks_admin_group_name              | DB Accounts Admin Group Name                  |
