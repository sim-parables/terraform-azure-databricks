## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "azure_tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "azure_client_id" {
  type        = string
  description = "Azure Service Principal Client ID with access to Storage Accounts"
  sensitive   = true
}

variable "azure_client_secret" {
  type        = string
  description = "Azure Service Principal Client Secret with access to Storage Accounts"
  sensitive   = true
}

variable "azure_resource_group" {
  type        = string
  description = "Azure Databricks Resource Group Name"
}

variable "azure_security_group_id" {
  type        = string
  description = "Microsoft Entra Security Group ID"
}

variable "databricks_storage_name" {
  type        = string
  description = "Databricks Workspace Storage Name"
}

variable "databricks_admin_group" {
  type        = string
  description = "Databricks Unity Catalog Administrator Group"
}

variable "databricks_workspace_number" {
  type        = number
  description = "Databricks Workspace ID (Number Only)"
}

variable "databricks_metastore_grants" {
  description = "List of Databricks Metastore Grant Mappings"
  type        = list(object({
    principal = string
    privileges = list(string)
  }))
}

variable "databricks_catalog_grants" {
  description = "List of Databricks Unity Catalog Grant Mappings"
  type        = list(object({
    principal = string
    privileges = list(string)
  }))
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "azure_container_name" {
  type        = string
  description = "Azure Storage Account Container Name"
  default     = "metastore"
}

variable "tags" {
  description = "Azure Resource Tag(s)"
  default     = {}
}