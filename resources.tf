terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [ azurerm.auth_session ]
    }
  }
}

locals {
  cloud   = "azure"
  program = "spark-databricks"
  project = "datasim"
}

locals  {
  tags = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURERM_RESOURCE_GROUP DATA SOURCE
##
## This Terraform block defines an Azure resource group using the azurerm provider with the alias 
## "auth_session". It specifies the resource group's name and location.
##
## Parameters:
## - `name`: The name of the resource group
## - `location`: The location where the resource group will be created
## ---------------------------------------------------------------------------------------------------------------------
data "azurerm_resource_group" "this" {
  provider = azurerm.auth_session
  name     = var.resource_group_name
}


## ---------------------------------------------------------------------------------------------------------------------
## AZURERM DATABRICKS WORKSPACE RESOURCE
##
## This resource provisions an Azure Databricks workspace.
## 
## Parameters:
## - `name`: The name of the Databricks workspace.
## - `resource_group_name`: The name of the resource group where the Databricks workspace will be created.
## - `location`: The location/region where the Databricks workspace will be deployed.
## - `sku`: The SKU (stock-keeping unit) of the Databricks workspace.
## - `managed_resource_group_name`: The name of the managed resource group associated with the Databricks workspace.
## ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_databricks_workspace" "this" {
  provider                    = azurerm.auth_session
  name                        = var.databricks_workspace_name
  resource_group_name         = data.azurerm_resource_group.this.name
  location                    = data.azurerm_resource_group.this.location
  sku                         = var.databricks_workspace_sku
  managed_resource_group_name = "${var.databricks_workspace_name}-resource-group"
}
