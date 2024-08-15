output "databricks_volume_file_paths" {
  description = "Databricks Unity Catalog Volume Paths"
  value       = databricks_file.this[*].id
}

output "databricks_schema_table_paths" {
  description = "Databricks Unity Catalog Schema Table Paths"
  value       = [
    for k,v in databricks_sql_table.this:
    v.id
  ]
}