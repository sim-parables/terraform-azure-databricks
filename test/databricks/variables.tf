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

variable "azure_region" {
  type        = string
  description = "Azure Resource Group Location"
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "DATABRICKS_CLI_PROFILE" {
  type        = string
  description = "Databricks CLI configuration Profile name for Databricks Accounts Authentication"
  default     = "AZURE_ACCOUNTS"
}

variable "DATABRICKS_CLUSTERS" {
  type        = number
  description = "Number representing the amount of Databricks Clusters to spin up"
  default     = 0
}

variable "databricks_workspace_name" {
  type        = string
  description = "Databricks Workspace Name"
  default     = "example-databricks-workspace"
}

variable "databricks_workspace_sku" {
  type        = string
  description = "Databricks Workspace Sku Type"
  default     = "premium"
}

variable "databricks_cluster_data_security_mode" {
  type        = string
  description = "Databricks Unity Catalog Feature to secure access/isolation. (Default: USER_ISOLATION)"
  default     = "USER_ISOLATION"
}

variable "databricks_instance_pool_node_max_capacity" {
  type        = number
  description = "Databricks Worker Nodes Instance Pool's Maximum Number of Allocated Nodes"
  default     = 2
}

variable "databricks_instance_pool_driver_max_capacity" {
  type        = number
  description = "Databricks Driver Instance Pool's Maximum Number of Allocated Nodes"
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}