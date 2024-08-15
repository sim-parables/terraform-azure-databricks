output "databricks_host" {
  description = "Databricks Workspace Host URL"
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}/"
}

output "databricks_workspace_id" {
  description = "Databricks Workspace ID"
  value       = azurerm_databricks_workspace.this.id
}

output "databricks_workspace_number" {
  description = "Databricks Workspace ID (Number Only)"
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "databricks_workspace_name" {
  description = "Databricks Workspace Name"
  value       = azurerm_databricks_workspace.this.name
}

output "databricks_secret_scope_name" {
  description = "Databricks Workspace Secret Scope Name"
  value       = module.databricks_secret_scope.databricks_secret_scope
}

output "databricks_secret_scope_id" {
  description = "Databricks Workspace Secret Scope Name"
  value       = module.databricks_secret_scope.databricks_secret_scope_id
}

output "databricks_secret_client_id_name" {
  description = "Databricks Workspace Secret Key for Client ID"
  value       = module.databricks_service_account_key_name_secret.databricks_secret_name
}

output "databricks_secret_client_secret_name" {
  description = "Databricks Workspace Secret Key for Client Secret"
  value       = module.databricks_service_account_key_data_secret.databricks_secret_name
}

output "databricks_external_location_url" {
  description = "Azure Metastore Bucket ABFS URL"
  value       = module.databricks_metastore.databricks_external_location_url
}

output "azure_keyvault_name" {
  description = "Azure Key Vault Name"
  value       = module.key_vault.key_vault_name
}

output "azure_keyvault_secret_client_id_name" {
  description = "Azure Key Vault Secret Key for Client ID"
  value       = module.key_vault_client_id.key_vault_secret_name
}

output "azure_keyvault_secret_client_secret_name" {
  description = "Azure Key Vault Secret Key for Client Secret"
  value       = module.key_vault_client_secret.key_vault_secret_name
}

output "databricks_admin_group_name" {
  description = "Databricks Accounts and Workspace Admin Group Name"
  value       = module.databricks_admin_group.databricks_group_name
}