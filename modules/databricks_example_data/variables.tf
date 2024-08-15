## ---------------------------------------------------------------------------------------------------------------------
## MODULE PARAMETERS
## These variables are expected to be passed in by the operator
## ---------------------------------------------------------------------------------------------------------------------

## ---------------------------------------------------------------------------------------------------------------------
## OPTIONAL PARAMETERS
## These variables have defaults and may be overridden
## ---------------------------------------------------------------------------------------------------------------------

variable "databricks_catalogs" {
  description = "Databricks Catalog Attributes"
  default     = null
  type        = list(object({
    name       = string
    comment    = string
    properties = object({})
  }))
}

variable "databricks_schemas" {
    description = "List of Databricks Unity Catalog Schema Attributes"
    default     = null
    type        = list(object({
        catalog_name = string
        schema_name  = string
        comment      = string
        properties   = object({})
    }))
}

variable "databricks_tables" {
    description = "List of Databricks Unity Catalog Table Attributes"
    default     = null
    type        = list(object({
        cluster_id         = string
        catalog_name       = string
        schema_name        = string
        table_name         = string
        table_type         = string
        data_source_format = string
        storage_location   = string
        comment            = string
        table_columns      = list(object({
            name     = string
            type     = string
            comment  = string
            nullable = bool
        }))
    }))
}

variable "databricks_volumes" {
    description = "List of Databricks Unity Catalog Volume Attributes"
    default     = null
    type        = list(object({
        catalog_name     = string
        schema_name      = string
        volume_name      = string
        volume_type      = string
        storage_location = string
        comment          = string
    }))
}

variable "databricks_files" {
    description = <<EOT
        List of Databricks Unity Catalog File Attributes.
        Optionally choose the file to use with either `file_path` or `content_base64`.
        `file_path` is obviously the local file path, and `content_base64` is the base64 encoded string
        of the file.
    EOT
    default     = null
    type        = list(object({
        catalog_name   = string
        schema_name    = string
        volume_name    = string
        file_name      = string
        content_base64 = string
    }))
}

