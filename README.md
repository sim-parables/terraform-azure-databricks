<p float="left">
  <img id="b-0" src="https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white" height="25px"/>
  <img id="b-1" src="https://img.shields.io/badge/Microsoft_Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white" height="25px"/>
  <img id="b-2" src="https://img.shields.io/github/actions/workflow/status/sim-parables/terraform-azure-databricks/tf-integration-test.yml?style=flat&logo=github&label=CD%20(June%202024)" height="25px"/>
</p>

# Terraform Azure Databricks Workspace & Unity Catalog Module

A reusable module for creating & configuring Databricks Workspaces with Unity Catalog on Azure.

## Usage

```hcl
##---------------------------------------------------------------------------------------------------------------------
## AZUREAD PROVIDER
##
## Azure Active Directory (AzureAD) provider.
##---------------------------------------------------------------------------------------------------------------------
provider "azuread" {
  alias = "auth_session"
}

##---------------------------------------------------------------------------------------------------------------------
## AZURERM PROVIDER
##
## Azure Resource Manager (Azurerm) provider authenticated with service account client credentials.
##
## Parameters:
## - `prevent_deletion_if_contains_resources`: Disable resource loss prevention mechanism.
##---------------------------------------------------------------------------------------------------------------------
provider "azurerm" {
  alias = "auth_session"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS Accounts PROVIDER
##
## This section defines the Databricks Accounts Provider with an alias for managing accounts.
## Authorization managed using Environment Variables
##   - DATABRICKS_ACCOUNT_ID
##   - DATABRICKS_CLIENT_ID
##   - DATABRICKS_CLIENT_SECRET
##
## Parameters:
## - `alias`: Alias for the provider.
## ---------------------------------------------------------------------------------------------------------------------
provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.cloud.databricks.com"
}

resource "random_string" "this" {
  special = false
  upper   = false
  length  = 4
}

locals {
  prefix         = "${local.program}-${local.project}-${random_string.this.id}"
  metastore_list = [
    {
      name                  = module.raw_metastore.metastore_name
      access_connector_id   = module.raw_metastore.access_connector_id
      external_location_url = module.raw_metastore.databricks_external_location_url
    },
    {
      name                  = module.output_metastore.metastore_name
      access_connector_id   = module.output_metastore.access_connector_id
      external_location_url = module.output_metastore.databricks_external_location_url
    }
  ]
}

## ---------------------------------------------------------------------------------------------------------------------
## AZURERM RESOURCES DATA SOURCE
## 
## Azure Resource Management Resource Group Configuration
## 
## Parameters:
## - `resource_group_name`: Name of Existing Azure Resource Group.
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_resource_group" "this" {
  provider = azurerm.auth_session
  name     = var.RESOURCE_GROUP_NAME
}


##---------------------------------------------------------------------------------------------------------------------
## RAW METASTORE MODULE
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
module "raw_metastore" {
  source = "../../modules/azure_metastore_bucket"

  databricks_storage_name       = "simparablesraw${local.prefix}"
  azure_container_name          = "raw"
  azure_resource_group          = data.azurerm_resource_group.this.name
  security_group_id             = var.SECURITY_GROUP_ID

  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}


##---------------------------------------------------------------------------------------------------------------------
## OUTPUT METASTORE MODULE
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
module "output_metastore" {
  source = "../../modules/azure_metastore_bucket"

  databricks_storage_name       = "simparablesoutput${local.prefix}"
  azure_container_name          = "output"
  azure_resource_group          = data.azurerm_resource_group.this.name
  security_group_id             = var.SECURITY_GROUP_ID

  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
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

  databricks_workspace_name = "example-workspace-${local.prefix}"
  resource_group_name       = data.azurerm_resource_group.this.name
  tags                      = var.tags

  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS UNITY CATALOG MODULE
##
## This module sets up the Databricks Unity Catalog on Azure.
##
## Parameters:
## - `azure_resource_group_name`: The name of the Azure resource group.
## - `azure_tenant_id`: Azure Tenant ID.
## - `azure_client_id`: Azure Service Principal ID to act as administrator for Databricks account.
## - `azure_client_secret`: Azure Service Principal client secret.
## - `databricks_account_id`: The ID of the Databricks account.
## - `databricks_administrator`: The administrator for the Databricks account.
## - `databricks_workspace_name`: The name of the Databricks workspace.
## - `databricks_workspace_id`: The ID of the Databricks workspace.
## - `databricks_workspace_host`: The host of the Databricks workspace.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_unity_catalog" {
  source                                        = "../../modules/databricks_unity_catalog"
  depends_on                                    = [ module.databricks_azure_workspace ]
  
  azure_resource_group_name                     = module.databricks_azure_workspace.azure_resource_group_name
  azure_tenant_id                               = data.azurerm_client_config.this.tenant_id
  azure_client_id                               = data.azurerm_client_config.this.client_id
  azure_client_secret                           = azuread_application_password.this.value
  databricks_account_id                         = data.databricks_current_config.accounts.account_id
  databricks_administrator                      = var.DATABRICKS_ADMINISTRATOR
  databricks_workspace_name                     = module.databricks_azure_workspace.databricks_workspace_name
  databricks_workspace_id                       = module.databricks_azure_workspace.databricks_workspace_id
  databricks_workspace_number                   = module.databricks_azure_workspace.databricks_workspace_number
  databricks_workspace_host                     = module.databricks_azure_workspace.databricks_host
  databricks_metastore_list                     = local.metastore_list

  providers = {
    azurerm.auth_session = azurerm.auth_session
    databricks.accounts  = databricks.accounts
    databricks.workspace = databricks.workspace
  }
}

```

## Inputs

| Name                      | Description                           | Type           | Required |
|:--------------------------|:--------------------------------------|:---------------|:---------|
| resource_group_name       | Name ofExisting Azure Resource Group  | String         | Yes      |
| databricks_workspace_sku  | DB Workspace Sku Type                 | String         | No       |
| databricks_workspace_name | DB Workspace Name                     | String         | No       |
| tags                      | Azure Resouce Tags                    | Object()       | No       |

## Outputs

| Name                        | Description                        |
|:----------------------------|:-----------------------------------|
| databricks_host             | DB Workspace URL                   |
| databricks_workspace_id     | DB Workspace ID                    |
| databricks_workspace_number | DB Workspace Unique Number         |
| databricks_workspace_name   | DB Workspace Name                  |