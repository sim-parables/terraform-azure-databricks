## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group Name"
}

variable "resource_group_location" {
  type        = string
  description = "Azure Resource Group Location"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault Name"
}

variable "security_group_id" {
  type        = string
  description = "Azure Security Group ID to Provision Storage Account Access"
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "key_vault_sku" {
  type        = string
  description = "Key Vault Name"
  default     = "standard"
}

variable "key_vault_soft_retention_days" {
  type        = number
  description = "Azure Key Vault Soft Retention Period for Key Delete in Days"
  default     = 7
}

variable "key_vault_permissions" {
  type        = list(string)
  description = "Azure Key Vault Access Policy Permissions"
  default     = [
      "List",
      "Get",
      "Backup",
      "Restore",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
}

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}