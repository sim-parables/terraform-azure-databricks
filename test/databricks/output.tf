output "databricks_workspace_host" {
  description = "Databricks Workspace Host URL"
  value       = module.databricks_workspace.databricks_host
}

output "databricks_workspace_id" {
  description = "Databricks Workspace ID"
  value       = module.databricks_workspace.databricks_workspace_id
}

output "databricks_workspace_number" {
  description = "Databricks Workspace ID (Number Only)"
  value       = module.databricks_workspace.databricks_workspace_number
}

output "databricks_workspace_name" {
  description = "Databricks Workspace Name"
  value       = module.databricks_workspace.databricks_workspace_name
}

output "databricks_access_token" {
  description = "Databricks Workspace Service Principal Access Token"
  value       = module.databricks_workspace_config.databricks_access_token
  sensitive   = true
}

output "databricks_secret_scope_name" {
  description = "Databricks Workspace Secret Scope Name"
  value       = module.databricks_workspace.databricks_secret_scope_name
}

output "databricks_secret_client_id_name" {
  description = "Databricks Workspace Secret Key for Client ID"
  value       = module.databricks_workspace.databricks_secret_client_id_name
}

output "databricks_secret_client_secret_name" {
  description = "Databricks Workspace Secret Key for Client Secret"
  value       = module.databricks_workspace.databricks_secret_client_secret_name
}

output "databricks_cluster_ids" {
  description = "List of Databricks Workspace Cluster IDs"
  value       = module.databricks_workspace_config.databricks_cluster_ids
}

output "databricks_external_location_url" {
  description = "Azure Metastore Bucket ABFS URL"
  value       = module.databricks_workspace.databricks_external_location_url
}

output "databricks_example_holdings_data_path" {
  description = "Databricks Example Holding Data Unity Catalog File Path"
  value       = module.databricks_workspace_config.databricks_example_holdings_data_path
}

output "databricks_example_weather_data_path" {
  description = "Databricks Example Weather Data Unity Catalog File Path"
  value       = module.databricks_workspace_config.databricks_example_weather_data_path
}

output "databricks_unity_catalog_table_paths" {
  description = "Databricks Unity Catalog Table Paths"
  value       = module.databricks_workspace_config.databricks_unity_catalog_table_paths
}

output "azure_keyvault_name" {
  description = "Azure Key Vault Name"
  value       = module.databricks_workspace.azure_keyvault_name
}

output "azure_keyvault_secret_client_id_name" {
  description = "Azure Key Vault Secret Key for Client ID"
  value       = module.databricks_workspace.azure_keyvault_secret_client_id_name
}

output "azure_keyvault_secret_client_secret_name" {
  description = "Azure Key Vault Secret Key for Client Secret"
  value       = module.databricks_workspace.azure_keyvault_secret_client_secret_name
}