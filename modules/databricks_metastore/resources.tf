terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases   = [ azurerm.auth_session, ]
    }

    databricks = {
      source = "databricks/databricks"
      configuration_aliases = [ 
        databricks.workspace,
        databricks.accounts 
      ]
    }
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## AZURERM_RESOURCE_GROUP DATA
##
## This data source retrieves information about an Azure resource group.
##
## Parameters:
## - `name`: The name of the Azure resource group.
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_resource_group" "this" {
  provider = azurerm.auth_session
  name     = var.azure_resource_group
}

locals {
  cloud   = "azure"
  program = "spark-databricks"
  project = "datasim"
}

locals  {
  tags            = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}

## ---------------------------------------------------------------------------------------------------------------------
## AZURERM DATABRICKS ACCESS CONNECTOR RESOURCE
##
## This resource defines an access connector for Azure Databricks.
##
## Parameters:
## - `name`: The name of the access connector.
## - `resource_group_name`: The name of the resource group where the access connector will be created.
## - `location`: The location/region where the access connector will be deployed.
## - `identity`: Specifies the identity type for the access connector. Here, it's set to "SystemAssigned".
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_databricks_access_connector" "this" {
  provider            = azurerm.auth_session
  name                = substr("${var.databricks_storage_name}-access-connector", 0, 64)
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }
}

##---------------------------------------------------------------------------------------------------------------------
## METASTORE BUCKET MODULE
##
## This module creates an ADLS Storage Account for Databricks Unity Catalog.
##
## Parameters:
## - `bucket_name`: ADLS storage account name.
## - `container_name`: ADLS storage account container name.
## - `resource_group_name`: Azure Resource Group name.
## - `resource_group_location`: Azure Resource Group location.
## - `security_group_id`: Azure AD Group ID to allow for access.
##---------------------------------------------------------------------------------------------------------------------
module "metastore_bucket" {
  source = "github.com/sim-parables/terraform-azure-blob-trigger//modules/adls_bucket?ref=8b292eb00c7052e10e2344ed8597d723f2f9389a"

  bucket_name                 = replace("${var.databricks_storage_name}bucket", "-", "")
  container_name              = var.azure_container_name
  resource_group_name         = data.azurerm_resource_group.this.name
  resource_group_location     = data.azurerm_resource_group.this.location
  security_group_id           = var.azure_security_group_id
  hierarchical_namespace      = true

  providers = {
    azurerm.auth_session = azurerm.auth_session
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS METASTORE MODULE
##
## This module creates Databricks metastores and assigns them to Databricks Workspaces for Unity Catalog.
##
## Parameters:
## - `databricks_metastore_name`: The name of the Databricks metastore.
## - `databricks_unity_admin_group`: The name of the owner group for the Databricks metastore.
## - `databricks_storage_root`: The root URL of the external storage associated with the metastore.
## - `cloud_region`: The region where the Databricks metastore is located.
##
## Providers:
## - `databricks.accounts`: The Databricks provider.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_metastore" {
  source   = "github.com/sim-parables/terraform-databricks//modules/databricks_metastore?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"

  databricks_metastore_name    = var.databricks_storage_name
  databricks_unity_admin_group = var.databricks_admin_group
  databricks_workspace_id      = var.databricks_workspace_number
  databricks_storage_root      = "abfss://${var.azure_container_name}@${module.metastore_bucket.bucket_name}.dfs.core.windows.net"
  databricks_metastore_grants  = var.databricks_metastore_grants
  cloud_region                 = data.azurerm_resource_group.this.location

  providers = {
    databricks.accounts = databricks.accounts
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS STORAGE CREDENTIAL RESOURCE
##
## This resource defines a storage credential in Databricks.
##
## Parameters:
## - `name`: The name of the storage credential.
## - `directory_id`: Azure Tenant ID.
## - `application_id`: Azure Service Principal client ID.
## - `client_secret`: Azure Service Principal client secret.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_storage_credential" "this" {
  provider   = databricks.workspace
  depends_on = [ module.databricks_metastore ]
  name       = "${var.databricks_storage_name}-credential"
  
  azure_service_principal {
    directory_id    = var.azure_tenant_id
    application_id = var.azure_client_id
    client_secret   = var.azure_client_secret
  }

  lifecycle {
    ignore_changes = [ azure_service_principal[0].client_secret ]
  }

  force_destroy = true
}


## ---------------------------------------------------------------------------------------------------------------------
## TIME SLEEP RESOURCE
##
## This resource defines a delay to allow time for Databricks Metastore grants to propagate.
##
## Parameters:
## - `create_duration`: The duration for the time sleep.
## ---------------------------------------------------------------------------------------------------------------------
resource "time_sleep" "grant_propogation" {
  depends_on = [ 
    module.databricks_metastore,
    databricks_storage_credential.this
  ]

  create_duration = "200s"
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS EXTERNAL LOCATION MODULE
##
## This resource defines an external location in Databricks and applies the location & metastore to catalog.
##
## Parameters:
## - `databricks_external_location_name`: The name of the external location.
## - `databricks_external_storage_url`: The URL of the external location.
## - `databricks_storage_credential_name`: The ID of the storage credential associated with this external location.
## - `databricks_catalog_grants`: List of Databricks Catalog roles mappings to grant to specific principal.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_external_location" {
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_external_location?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on = [
    databricks_storage_credential.this,
    module.databricks_metastore,
    time_sleep.grant_propogation
  ]

  databricks_external_location_name = var.databricks_storage_name
  databricks_external_storage_url   = "abfss://${var.azure_container_name}@${module.metastore_bucket.bucket_name}.dfs.core.windows.net"
  databricks_storage_credential_id  = databricks_storage_credential.this.id
  databricks_catalog_grants         = var.databricks_catalog_grants

  providers = {
    databricks.workspace = databricks.workspace
  }
}
