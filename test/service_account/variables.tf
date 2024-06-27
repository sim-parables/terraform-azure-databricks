## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "application_display_name" {
  type        = string
  description = "Service Account AD Application Name"
}

variable "role_name" {
  type        = string
  description = "Service Account Role Name"
}

variable "security_group_name" {
  type        = string
  description = "Security Group Name"
}

variable "azure_region" {
  type        = string
  description = "Azure Resource Group Location"
}

variable "DATABRICKS_ACCOUNT_ID" {
  type        = string
  description = "Databricks Account ID"
  sensitive   = true
}

variable "DATABRICKS_ACCOUNT_SCIM_TOKEN" {
  type        = string
  description = "Databricks Account System for Cross-domain Identity Management (SCIM) Token"
  sensitive   = true
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "GITHUB_REPOSITORY_OWNER" {
  type        = string
  description = "Github Actions Default ENV Variable for the Repo Owner"
  default     = "sim-parables"
}

variable "GITHUB_REPOSITORY" {
  type        = string
  description = "Github Actions Default ENV Variable for the Repo Path"
  default     = "sim-parables/terraform-azure-databricks"
}

variable "GITHUB_REF" {
  type        = string
  description = "Github Actions Default ENV Variable for full form of the Branch or Tag"
  default     = "refs/heads/main"
}

variable "GITHUB_ENV" {
  type        = string
  description = <<EOT
    Github Environment in which the Action Workflow's Job or Step is running. Ex: production.
    This is not found in Github Action's Default Environment Variables and will need to be
    defined manually.
  EOT
  default     = "production"
}

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}