## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "Name of Existing Azure Resource Group"
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

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

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}