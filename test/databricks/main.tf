terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    databricks = {
      source = "databricks/databricks"
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

  metastore_grants = [
    {
      principal  = module.databricks_admin_group.databricks_group_name
      privileges = ["CREATE_CATALOG", "CREATE_CONNECTION", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
    }
  ]

  catalog_grants = [
    {
      principal  = module.databricks_admin_group.databricks_group_name
      privileges = ["CREATE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "CREATE_VOLUME"]
    }
  ]

  maven_libraries = [
    "org.apache.hadoop:hadoop-azure-datalake:3.3.3",
    "org.apache.hadoop:hadoop-common:3.3.3",
    "org.apache.hadoop:hadoop-azure:3.3.3"
  ]

  # Define Spark environment variables
  spark_environment_variables = {
    "CLOUD_PROVIDER": upper(local.cloud),
    "RAW_DIR": module.databricks_metastore.databricks_external_location_url,
    "OUTPUT_DIR": module.databricks_metastore.databricks_external_location_url,
    "SERVICE_ACCOUNT_KEY_NAME": module.key_vault_client_id.key_vault_secret_name,
    "SERVICE_ACCOUNT_KEY_SECRET": module.key_vault_client_secret.key_vault_secret_name,
    "AZURE_TENANT_ID": data.azurerm_client_config.this.tenant_id
  }

  # Define Spark configuration variables
  spark_configuration_variables = {
    "fs.azure.account.auth.type": "OAuth",
    "fs.azure.account.oauth.provider.type": "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
    "fs.azure.account.oauth2.client.id": "{{secrets/${module.databricks_secret_scope.databricks_secret_scope_id}/${module.databricks_service_account_key_name_secret.databricks_secret_name}}}",
    "fs.azure.account.oauth2.client.secret": "{{secrets/${module.databricks_secret_scope.databricks_secret_scope_id}/${module.databricks_service_account_key_data_secret.databricks_secret_name}}}",
    "fs.azure.account.oauth2.client.endpoint": "https://login.microsoftonline.com/${data.azurerm_client_config.this.tenant_id}/oauth2/token",
    "spark.databricks.driver.strace.enabled": "true"
  }

  tags = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
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

  name     = "${local.prefix}-resource-group"
  location = var.azure_region
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

  databricks_workspace_name = "${local.prefix}-workspace"
  databricks_workspace_sku  = "premium"
  resource_group_name       = azurerm_resource_group.this.name
  tags                      = var.tags

  providers = {
    azurerm.auth_session = azurerm.auth_session
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
  alias      = "workspace"
  host       = module.databricks_workspace.databricks_host
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
  depends_on = [ module.databricks_workspace ]
  
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
  end_date_relative = var.client_secret_expiration
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
  source                  = "../../modules/azure_key_vault"
  depends_on              = [ azurerm_resource_group.this ]

  key_vault_name          = "${local.prefix}-key-vault"
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
  source                  = "../../modules/azure_key_vault_secret"
  depends_on              = [ module.key_vault ]
  
  key_vault_id           = module.key_vault.key_vault_id
  key_vault_secret_name  = local.client_id_name
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
  source                  = "../../modules/azure_key_vault_secret"
  depends_on              = [ module.key_vault ]
  
  key_vault_id           = module.key_vault.key_vault_id
  key_vault_secret_name  = local.client_secret_name
  key_vault_secret_value = azuread_application_password.this.value
  
  providers = {
    azurerm.auth_session = azurerm.auth_session
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
  alias     = "accounts"
  auth_type = "oauth-m2m"
  profile   = var.DATABRICKS_CLI_PROFILE
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS CURRENT USER DATA
##
## Retrieves information about the current Service Principal in Databricks. This will be the Databricks
## Accounts admin found in the Databricks CLI Profile.
## ---------------------------------------------------------------------------------------------------------------------
data "databricks_current_user" "this" {
  provider   = databricks.workspace
  depends_on = [ module.databricks_workspace ]
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
  depends_on = [ module.databricks_workspace ]
  
  service_principal_id = data.databricks_current_user.this.id
  role                 = "account_admin"
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
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_group?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on = [ databricks_service_principal_role.this ]
  
  group_name                  = "${local.prefix}-admin-group"
  allow_cluster_create        = true
  allow_databricks_sql_access = true
  allow_instance_pool_create  = true
  member_ids                  = [
    data.databricks_current_user.this.id
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
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_group?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on = [ databricks_service_principal_role.this ]
  
  group_name                  = "${local.prefix}-user-group"
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
  source     = "../../modules/databricks_metastore"
  depends_on = [ module.databricks_admin_group ]

  azure_tenant_id               = data.azurerm_client_config.this.tenant_id
  azure_client_id               = data.azurerm_client_config.this.client_id
  azure_client_secret           = azuread_application_password.this.value
  azure_container_name          = "metastore"
  azure_resource_group          = azurerm_resource_group.this.name
  azure_security_group_id       = var.SECURITY_GROUP_ID
  databricks_storage_name       = "${azurerm_resource_group.this.location}-${local.prefix}"
  databricks_metastore_grants   = local.metastore_grants
  databricks_catalog_grants     = local.catalog_grants
  databricks_admin_group        = module.databricks_admin_group.databricks_group_name
  databricks_workspace_number   = module.databricks_workspace.databricks_workspace_number

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
  source   = "github.com/sim-parables/terraform-databricks//modules/databricks_secret_scope?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on   = [ module.databricks_metastore ]

  secret_scope = local.secret_scope

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
  source      = "github.com/sim-parables/terraform-databricks//modules/databricks_secret?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on  = [ module.databricks_metastore ]
  
  secret_scope_id = module.databricks_secret_scope.databricks_secret_scope_id
  secret_name     = local.client_id_name
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
  source       = "github.com/sim-parables/terraform-databricks//modules/databricks_secret?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on   = [ module.databricks_metastore ]
  
  secret_scope_id = module.databricks_secret_scope.databricks_secret_scope_id
  secret_name     = local.client_secret_name
  secret_data     = azuread_application_password.this.value

  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS DRIVER NODE INSTANCE POOL MODULE
## 
## This module creates an instance pool in a Databricks workspace specifically for driver nodes.
## 
## Parameters:
## - `instance_pool_name`: Specifies the name of the instance pool
## - `instance_pool_max_capacity`: Specifies the maximum capacity of the instance pool
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_instance_pool_driver" {
  source       = "github.com/sim-parables/terraform-databricks//modules/databricks_instance_pool?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on   = [ module.databricks_metastore ]
  
  instance_pool_name         = "${local.prefix}-driver-instance-pool"
  instance_pool_max_capacity = var.databricks_instance_pool_driver_max_capacity

  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS WORKER NODE INSTANCE POOL MODULE
## 
## This module creates an instance pool in a Databricks workspace specifically for worker nodes.
## 
## Parameters:
## - `instance_pool_name`: Specifies the name of the instance pool
## - `instance_pool_max_capacity`: Specifies the maximum capacity of the instance pool
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_instance_pool_node" {
  source       = "github.com/sim-parables/terraform-databricks//modules/databricks_instance_pool?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on   = [ module.databricks_metastore ]
  
  instance_pool_name         = "${local.prefix}-node-instance-pool"
  instance_pool_max_capacity = var.databricks_instance_pool_node_max_capacity

  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS ENGINEER GROUP MODULE
## 
## This module sets up an engineer group in a Databricks workspace.
## 
## Parameters:
## - `group_name`: Specifies the name of the engineer group.
## - `allow_cluster_create`: Specify whether to allow the group to create clusters.
## - `allow_databricks_sql_access`: Specify whether to allow SQL access to Databricks.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_engineer_group" {
  source       = "github.com/sim-parables/terraform-databricks//modules/databricks_group?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on   = [ module.databricks_metastore ]
  
  group_name                  = "${local.prefix}-engineer-group"
  allow_cluster_create        = true
  allow_databricks_sql_access = true

  providers = {
    databricks.workspace = databricks.workspace
  }
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS CLUSTER POLICY MODULE
## 
## This module sets up a cluster policy in a Databricks workspace.
## 
## Parameters:
## - `cluster_policy_name`: Specifies the name of the cluster policy.
## - `group_name`: Specify the name of the engineer group to associate the policy with.
## - `data_security_mode`: Databrick cluster security mode
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_cluster_policy" {
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_cluster_policy?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on = [ module.databricks_engineer_group ]
  
  cluster_policy_name = "${local.prefix}-cluster-policy"
  group_name          = module.databricks_engineer_group.databricks_group_name
  data_security_mode  = var.databricks_cluster_data_security_mode

  providers = {
    databricks.workspace = databricks.workspace
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS CLUSTER MODULE
## 
## This module sets up a Databricks cluster with the specified configurations.
## 
## Parameters:
## - `cluster_name`: Specify the name of the Databricks cluster.
## - `node_instance_pool_id`: Specify the instance pool IDs for worker nodes.
## - `driver_instance_pool_id`: Specify the instance pool IDs for driver nodes.
## - `cluster_policy_name`: Specify the name of the cluster policy.
## - `cluster_policy_id`: Specify the ID of the cluster policy.
## - `spark_env_variable`: Define Spark environment variables.
## - `spark_conf_variable`: Define Spark configuration variables.
## - `maven_libraries`: Define Maven libraries for the cluster.
## ---------------------------------------------------------------------------------------------------------------------
module "databricks_cluster" {
  source     = "github.com/sim-parables/terraform-databricks//modules/databricks_cluster?ref=e08a6fb2e91c019d8f082002e7f40f0fdfe61e28"
  depends_on = [ module.databricks_cluster_policy ]
  
  cluster_name            = "${local.prefix}-cluster"
  node_instance_pool_id   = module.databricks_instance_pool_node.instance_pool_id
  driver_instance_pool_id = module.databricks_instance_pool_driver.instance_pool_id
  cluster_policy_name     = module.databricks_cluster_policy.cluster_policy_name
  cluster_policy_id       = module.databricks_cluster_policy.cluster_policy_id
  maven_libraries         = local.maven_libraries
  spark_env_variable      = local.spark_environment_variables
  spark_conf_variable     = local.spark_configuration_variables

  providers = {
    databricks.workspace = databricks.workspace
  }
}