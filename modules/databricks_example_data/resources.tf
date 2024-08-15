terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
      configuration_aliases = [ 
        databricks.workspace,
      ]
    }
  }
}

## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS CATALOG RESOURCE
##
## This resource defines a Databricks UC Catalog.
##
## Parameters:
## - `catalog_name`: Databricks Unity Catalog name.
## - `name`: Databricks Unity Catalog Schema name.
## - `comment`: Commentary to add to Unity Catalog Schema.
## - `properties`: Mapping of Unity Catalog Schema properties.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_catalog" "this" {
  provider = databricks.workspace
  for_each = tomap({ for t in coalesce(var.databricks_catalogs, []) : "${t.name}" => t })

  name         = each.value.name
  comment      = each.value.comment
  properties   = each.value.properties
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SCHEMA RESOURCE
##
## This resource defines a Databricks Unity Catalog Schema.
##
## Parameters:
## - `catalog_name`: Databricks Unity Catalog name.
## - `name`: Databricks Unity Catalog Schema name.
## - `comment`: Commentary to add to Unity Catalog Schema.
## - `properties`: Mapping of Unity Catalog Schema properties.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_schema" "this" {
  provider   = databricks.workspace
  depends_on = [ databricks_catalog.this ]
  for_each   = tomap({ for t in coalesce(var.databricks_schemas, []) : "${t.schema_name}" => t })
  
  catalog_name = each.value.catalog_name
  name         = each.value.schema_name
  comment      = each.value.comment
  properties   = each.value.properties
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS VOLUME RESOURCE
##
## This resource defines a Databricks Unity Catalog Volume.
##
## Parameters:
## - `catalog_name`: Databricks Unity Catalog name.
## - `schema_name`: Databricks Unity Catalog Schema name.
## - `name`: Databricks Unity Catalog Volume name.
## - `volume_type`: Unity Catalog Volume type.
## - `comment`: Commentary to add to Unity Catalog Schema.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_volume" "this" {
  provider   = databricks.workspace
  depends_on = [ databricks_schema.this ]
  for_each = tomap({ for t in coalesce(var.databricks_volumes, []) : "${t.volume_name}" => t })
  
  catalog_name     = each.value.catalog_name
  schema_name      = each.value.schema_name
  name             = each.value.volume_name
  volume_type      = each.value.volume_type
  storage_location = "${each.value.storage_location}/volumes/${each.value.volume_name}"
  comment          = each.value.comment
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS FILE RESOURCE
##
## This resource defines a Databricks Unity Catalog File.
##
## Parameters:
## - `path`: Databricks Unity Catalog File path.
## - `content_base64`: Base64 encoded content for file upload.
## ---------------------------------------------------------------------------------------------------------------------
resource "databricks_file" "this" {
  provider   = databricks.workspace
  depends_on = [ databricks_volume.this ]
  count      = var.databricks_files != null ? length(var.databricks_files): 0

  path         = "/Volumes/${var.databricks_files[count.index].catalog_name}/${var.databricks_files[count.index].schema_name}/${var.databricks_files[count.index].volume_name}/${var.databricks_files[count.index].file_name}"
  content_base64 = var.databricks_files[count.index].content_base64
}


## ---------------------------------------------------------------------------------------------------------------------
## DATABRICKS SQL TABLE RESOURCE
##
## This resource defines a Databricks Unity Catalog SQL Table.
##
## Parameters:
## - `path`: Databricks Unity Catalog File path.
## - `content_base64`: Base64 encoded content for file upload.
## ---------------------------------------------------------------------------------------------------------------------

resource "databricks_sql_table" "this" {
  provider   = databricks.workspace
  depends_on = [ databricks_schema.this ]
  for_each   = tomap({ for t in coalesce(var.databricks_tables, []) : "${t.table_name}" => t })

  catalog_name       = each.value.catalog_name
  schema_name        = each.value.schema_name
  name               = each.value.table_name
  table_type         = each.value.table_type
  data_source_format = each.value.data_source_format
  storage_location   = "${each.value.storage_location}/tables/${each.value.table_name}"
  comment            = each.value.comment

  dynamic "column" {
    for_each = tomap({ for c in coalesce(each.value.table_columns, []) : "${c.name}" => c })

    content {
      name     = column.value.name
      type     = column.value.type
      comment  = column.value.comment
      nullable = column.value.nullable
    }
  }
}
