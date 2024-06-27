output "metastore_name" {
  description = "Azure Databricks Metastore Name"
  value       = var.databricks_storage_name
}

output "access_connector_id" {
  description = "Azure Databricks Access Connector ID"
  value       = azurerm_databricks_access_connector.this.id
}

output "storage_credential_id" {
  description = "Azure Databricks Storage Credential ID"
  value       = databricks_storage_credential.this.id
}

output "databricks_external_location_url" {
  description = "Azure Metastore Bucket abfss URL"
  value       = "abfss://${var.azure_container_name}@${module.metastore_bucket.bucket_name}.dfs.core.windows.net"
}

