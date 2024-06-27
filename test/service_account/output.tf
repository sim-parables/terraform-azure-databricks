output "service_account_client_id" {
  description = "Azure Service Account Client ID"
  value       = module.azure_service_account.client_id
}

output "service_account_client_secret" {
  description = "Azure Service Account Client Secret"
  value       = nonsensitive(module.azure_service_account.client_secret)
  sensitive   = true
}

output "service_account_application_id" {
  description = "Azure Service Account Application ID"
  value       = module.azure_service_account.application_id
}

output "security_group_id" {
  description = "Microsoft Entra ID Group Name"
  value       = module.azure_service_account.security_group_id
}