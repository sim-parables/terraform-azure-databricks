## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

variable "key_vault_id" {
  type        = string
  description = "Existing Key Vault ID"
}

variable "key_vault_secret_name" {
  type        = string
  description = "Key Vault Secret Name"
}

variable "key_vault_secret_value" {
  type        = string
  description = "Key Vault Secret Value"
  sensitive   = true
}

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "Azure Resource Tag(s)"
  default     = {}
}