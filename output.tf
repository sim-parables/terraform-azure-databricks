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
