terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
    }

    databricks = {
      source  = "databricks/databricks"
    }
  }

  backend "remote" {
    organization = "sim-parables"
    workspaces {
      name = "ci-cd-azure-workspace"
    }
  }
}

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
## AZURERM CLIENT CONFIG DATA SOURCE
## 
## Azure Resource Management Client Configuration
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_client_config" "this" {
  provider = azurerm.auth_session
}

resource "random_string" "this" {
  special = false
  upper   = false
  length  = 4
}

locals {
  cloud   = "azure"
  program = "spark-databricks"
  project = "datasim"
}

locals {
  prefix             = "${random_string.this.id}-${local.program}-${local.project}"
  secret_scope       = upper(local.cloud)
  client_id_name     = "${local.prefix}-sp-client-id"
  client_secret_name = "${local.prefix}-sp-client-secret"
  catalog_name       = "${local.project}_catalog"
  schema_name        = "db_terraform"

  metastore_grants = [
    "CREATE_CATALOG", "CREATE_CONNECTION", "CREATE_EXTERNAL_LOCATION", 
    "CREATE_STORAGE_CREDENTIAL",
  ]

  catalog_grants = [
    "CREATE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "CREATE_VOLUME", 
    "USE_CATALOG", "USE_SCHEMA", "READ_VOLUME", "SELECT",
  ]

  # Define Spark environment variables
  spark_environment_variables = {
    "CLOUD_PROVIDER": upper(local.cloud),
    "RAW_DIR": module.databricks_workspace.databricks_external_location_url,
    "OUTPUT_DIR": module.databricks_workspace.databricks_external_location_url,
    "SERVICE_ACCOUNT_KEY_NAME": module.databricks_workspace.azure_keyvault_secret_client_id_name,
    "SERVICE_ACCOUNT_KEY_SECRET": module.databricks_workspace.azure_keyvault_secret_client_secret_name,
    "AZURE_TENANT_ID": data.azurerm_client_config.this.tenant_id
  }

  # Define Spark configuration variables
  spark_configuration_variables = {
    "fs.azure.account.auth.type": "OAuth",
    "fs.azure.account.oauth.provider.type": "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
    "fs.azure.account.oauth2.client.id": "{{secrets/${module.databricks_workspace.databricks_secret_scope_id}/${module.databricks_workspace.databricks_secret_client_id_name}}}",
    "fs.azure.account.oauth2.client.secret": "{{secrets/${module.databricks_workspace.databricks_secret_scope_id}/${module.databricks_workspace.databricks_secret_client_secret_name}}}",
    "fs.azure.account.oauth2.client.endpoint": "https://login.microsoftonline.com/${data.azurerm_client_config.this.tenant_id}/oauth2/token",
    "spark.databricks.driver.strace.enabled": "true"
  }

  databricks_cluster_library_files = [
    {
      file_name      = "hadoop-azure-datalake_3.3.3.jar"
      content_base64 = data.http.hadoop_azure_datalake_jar.response_body_base64
    },
    {
      file_name      = "hadoop-common_3.3.3.jar"
      content_base64 = data.http.hadoop_common_jar.response_body_base64
    },
    {
      file_name      = "hadoop-azure_3.3.3.jar"
      content_base64 = data.http.hadoop_azure_jar.response_body_base64
    },
  ]

  databricks_azure_attributes = {
    attributes = {
        availability       = "SPOT_AZURE"
        first_on_demand    = 0
        spot_bid_max_price = -1
    }
  }

  tags = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}


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
  host      = module.databricks_workspace.databricks_host
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS WORKSPACE CONFIG MODULE
## 
## This module configures a Databricks Workspace with the resources necessary to start utilizing spark/azure compute,
## and a bootstrapped Unity Catalog. Databricks Assets Bundles will also be ready to deploy onto the workspace with 
## pytest scripts ready to test spark capabilities.
## 
## Parameters:
## - `DATABRICKS_CLUSTERS`: Number of clusters to deploy in Databricks Workspace.
## - `databricks_admin_group`: Name of Databricks Accounts adming group.
## - `databricks_cluster_name`: Prefix for Databricks Clusters. 
## - `databricks_catalog_name`: Name of Databricks Unity Catalog.
## - `databricks_catalog_external_location_url`: Cloud Storage URL.
## - `databricks_cluster_spark_env_variable`:
## - `databricks_spark_env_variable`: Map of Spark environment variables.
## - `databricks_spark_conf_variable`: Map of Spark configuration variables.
## - `databricks_cluster_library_paths`: List of Databricks Unity Catalog Library Volume to be included in the ALLOWED LIST.
## - `databricks_cluster_jar_libraries`: List of JAR files to install on cluster which can be found in Databricks Unity Catalog Library Volume.
## - `databricks_cluster_azure_attributes`: Map of Azure Compute Configurations for Databricks Clusters.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_workspace_config" {
  source   = "github.com/sim-parables/terraform-databricks?ref=c05bc4f94a1167c550496f2f3565fa319f68bf8b"
  depends_on = [ module.databricks_workspace ]
  
  DATABRICKS_CLUSTERS                      = var.DATABRICKS_CLUSTERS
  databricks_cluster_name                  = "${local.prefix}-cluster"
  databricks_catalog_name                  = "${local.prefix}-metastore"
  databricks_schema_name                   = local.schema_name
  databricks_catalog_external_location_url = module.databricks_workspace.databricks_external_location_url
  databricks_cluster_spark_env_variable    = local.spark_environment_variables
  databricks_cluster_spark_conf_variable   = local.spark_configuration_variables
  databricks_cluster_library_files         = local.databricks_cluster_library_files
  databricks_cluster_azure_attributes      = local.databricks_azure_attributes
  databricks_workspace_group               = "${local.prefix}-group"

  providers = {
    databricks.accounts = databricks.accounts
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## HTTP DATA SOURCE
## 
## Download contents of hadoop-azure-datalake-3.3.3 jar Databricks Unity Catalog LIBRARIES Volume.
## 
## Parameters:
## - `url`: Sample data URL.
## - `request_headers`: Mapping of HTTP request headers.
## ---------------------------------------------------------------------------------------------------------------------
data "http" "hadoop_azure_datalake_jar" {
  url = "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/3.3.3/hadoop-azure-datalake-3.3.3.jar"

  # Optional request headers
  request_headers = {
    Accept  = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
    Accept-Encoding = "gzip, deflate, br, zstd"
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## HTTP DATA SOURCE
## 
## Download contents of hadoop-common-3.3.3 jar Databricks Unity Catalog LIBRARIES Volume.
## 
## Parameters:
## - `url`: Sample data URL.
## - `request_headers`: Mapping of HTTP request headers.
## ---------------------------------------------------------------------------------------------------------------------
data "http" "hadoop_common_jar" {
  url = "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.3/hadoop-common-3.3.3.jar"

  # Optional request headers
  request_headers = {
    Accept  = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
    Accept-Encoding = "gzip, deflate, br, zstd"
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## HTTP DATA SOURCE
## 
## Download contents of org.apache.hadoop:hadoop-azure:3.3.3 jar Databricks Unity Catalog LIBRARIES Volume.
## 
## Parameters:
## - `url`: Sample data URL.
## - `request_headers`: Mapping of HTTP request headers.
## ---------------------------------------------------------------------------------------------------------------------
data "http" "hadoop_azure_jar" {
  url = "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/3.3.3/hadoop-azure-3.3.3.jar"

  # Optional request headers
  request_headers = {
    Accept  = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
    Accept-Encoding = "gzip, deflate, br, zstd"
  }
}
