## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "SECURITY_GROUP_ID" {
  type        = string
  description = "Microsoft Entra Security Group ID"
}

variable "DATABRICKS_ADMINISTRATOR" {
  type        = string
  description = "Email Adress for the Databricks Unity Catalog Administrator"
}

variable "azure_resource_group_name" {
  type        = string
  description = "Name of Existing Azure Resource Group"
}

variable "azure_region" {
  type        = string
  description = "Azure Resource Group Location"
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "azure_key_vault_name" {
  type        = string
  description = "Azure Key Vault Name"
  default     = "example_key_vault"
}

variable "azure_databricks_client_id_secret_name" {
  type        = string
  description = "Azure Client ID AKV and Databricks Secret Name for Databricks Service Principal"
  default     = "databricks-sp-client-id"
}

variable "azure_databricks_client_secret_secret_name" {
  type        = string
  description = "Azure Client Secret AKV and Databricks Secret Name for Databricks Service Principal"
  default     = "databricks-sp-client-secret"
}

variable "azure_databricks_client_secret_expiration" {
  type        = string
  description = "Service Account Secret Relative Expiration from Creation"
  default     = "1h"
}

variable "databricks_workspace_sku" {
  type        = string
  description = "Databricks Workspace Sku Type"
  default     = "standard"
}

variable "databricks_workspace_name" {
  type        = string
  description = "Databricks Workspace Name"
  default     = "example-databricks-workspace"
}

variable "databricks_group_prefix" {
  type        = string
  description = "Databricks Accounts and Workspace Group Name Prefix"
  default     = "example-group"
}

variable "databricks_catalog_name" {
  type        = string
  description = "Display Name for Databricks Accounts Metastore Catalog"
  default     = "example_metastore"
}

variable "databricks_catalog_grants" {
  description = <<EOT
    List of Databricks Catalog Specific Grants. Default privileges when creating a metastore
    should include: CREATE_SCHEMA, CREATE_FUNCTION, CREATE_TABLE, CREATE_VOLUME, 
        USE_CATALOG, USE_SCHEMA, READ_VOLUME, SELECT
  EOT
  default     = []
  type        = list(string)
}

variable "databricks_metastore_grants" {
  description = <<EOT
    List of Databricks Metastore Specific Grants. Default privileges when creating a metastore
    should include: CREATE_CATALOG, CREATE_CONNECTION, CREATE_EXTERNAL_LOCATION, CREATE_STORAGE_CREDENTIAL
  EOT
  default     = []
  type        = list(string)
}

variable "databricks_secret_scope_name" {
  type        = string
  description = "Databricks Workspace Secret Scope Name"
  default     = "example-secret"
}

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}