terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }

  backend "remote" {
    # The name of your Terraform Cloud organization.
    organization = "sim-parables"

    # The name of the Terraform Cloud workspace to store Terraform state files in.
    workspaces {
      name = "ci-cd-azure-service-account-workspace"
    }
  }
}

##---------------------------------------------------------------------------------------------------------------------
## AZUREAD PROVIDER
##
## Azure Active Directory (AzureAD) provider authenticated with CLI.
##---------------------------------------------------------------------------------------------------------------------
provider "azuread" {
  alias = "tokengen"
}

##---------------------------------------------------------------------------------------------------------------------
## AZURRM PROVIDER
##
## Azure Resource Manager (Azurerm) provider authenticated with CLI.
##---------------------------------------------------------------------------------------------------------------------
provider "azurerm" {
  alias = "tokengen"
  features {}
}


resource "random_string" "this" {
  special = false
  upper   = false
  length  = 4
}


data "azuread_application_published_app_ids" "this" {
  provider = azuread.tokengen
}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.this.result["MicrosoftGraph"]
}

locals {
  cloud   = "azure"
  program = "spark-databricks"
  project = "datasim"
}

locals {
  prefix             = "${local.program}-${local.project}-${random_string.this.id}"
  client_id_name     = "${local.prefix}-sp-client-id"
  client_secret_name = "${local.prefix}-sp-client-secret"
  oidc_subject       = [
    {
      display_name = "example-federated-idp-dataflow-readwrite"
      subject      = "repo:${var.GITHUB_REPOSITORY}:environment:${var.GITHUB_ENV}"
    },
    {
      display_name = "example-federated-idp-dataflow-read"
      subject      = "repo:${var.GITHUB_REPOSITORY}:ref:${var.GITHUB_REF}"
    }
  ]

  api_permissions = [
    {
      resource_app_id    = data.azuread_application_published_app_ids.this.result["MicrosoftGraph"]
      resource_object_id = data.azuread_service_principal.msgraph.object_id
      scope_ids          = []
      role_ids = [
        data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"],
        data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"],
        data.azuread_service_principal.msgraph.app_role_ids["AppRoleAssignment.ReadWrite.All"],
        data.azuread_service_principal.msgraph.app_role_ids["Directory.ReadWrite.All"],
        data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"],
        data.azuread_service_principal.msgraph.app_role_ids["Group.ReadWrite.All"],
      ]
    }
  ]

  app_roles = [
    {
      allowed_member_types = ["Application", "User"]
      description          = "Databricks Account and Unity Catalog Admin"
      display_name         = "Admin"
      value                = "admin"
    }
  ]

  tags = merge(var.tags, {
    program = local.program
    project = local.project
    env     = "dev"
  })
}

data "azurerm_client_config" "current" {
  provider = azurerm.tokengen
}

##---------------------------------------------------------------------------------------------------------------------
## AZURE APPLICATION TEMPLATE DATA SOURCE
##
## An Azure Application Template for Databricks SCIM Provisioning Connector on Databricks Accounts.
##
## Parameters:
## - `display_name`: The display name of the Azure application template.
##---------------------------------------------------------------------------------------------------------------------
data "azuread_application_template" "this" {
  display_name = "Azure Databricks SCIM Provisioning Connector"
}

##---------------------------------------------------------------------------------------------------------------------
## AZURE SERVICE ACCOUNT MODULE
##
## This module provisions an Azure service account along with associated roles and security groups.
##
## Parameters:
## - `application_display_name`: The display name of the Azure application.
## - `application_template_id`: Azure App Gallery application template ID.
## - `application_app_roles`: List of Azure application app role mappings.
## - `api_permissions`: List of API permissions to grant to Azure Application.
## - `role_name`: The name of the role for the Azure service account.
## - `security_group_name`: The name of the security group.
##---------------------------------------------------------------------------------------------------------------------
module "azure_service_account" {
  source     = "github.com/sim-parables/terraform-azure-service-account.git?ref=8a1f4741833287f62fdd6f0273d6914e3395a862"
  depends_on = [data.azurerm_client_config.current]

  application_display_name = var.application_display_name
  application_template_id  = data.azuread_application_template.this.template_id
  application_app_roles    = local.app_roles
  api_permissions          = local.api_permissions
  security_group_name      = var.security_group_name
  role_name                = var.role_name
  
  roles_list = [
    "Microsoft.Resources/subscriptions/providers/read",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Authorization/roleAssignments/*",
    "Microsoft.Databricks/*",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.KeyVault/vaults/*",
    "Microsoft.KeyVault/locations/deletedVaults/*",
    "Microsoft.KeyVault/locations/operationResults/*"
  ]

  providers = {
    azuread.tokengen = azuread.tokengen
    azurerm.tokengen = azurerm.tokengen
  }
}

##---------------------------------------------------------------------------------------------------------------------
## AZURE APPLICATION IDENTITY FEDERATION CREDENTIALS MODULE
##
## This module creates a Federated Identity Credential for the application to authenticate with Github Actions
## without client credetials through OpenID Connect protocol.
##
## Parameters:
## - `application_id`: Azure service account application ID.
## - `display_name`: Identity Federation Credential display name.
## - `subject`: OIDC authentication subject.
##---------------------------------------------------------------------------------------------------------------------
module "azure_application_federated_identity_credential" {
  source     = "github.com/sim-parables/terraform-azure-service-account.git?ref=8a1f4741833287f62fdd6f0273d6914e3395a862//modules/identity_federation"
  depends_on = [module.azure_service_account]
  for_each   = tomap({ for t in local.oidc_subject : "${t.display_name}-${t.subject}" => t })

  application_id = module.azure_service_account.application_id
  display_name   = each.value.display_name
  subject        = each.value.subject

  providers = {
    azuread.tokengen = azuread.tokengen
  }
}


resource "azuread_synchronization_secret" "this" {
  provider   = azuread.tokengen
  depends_on = [ 
    module.azure_service_account,
    module.azure_application_federated_identity_credential
  ]

  service_principal_id = module.azure_service_account.service_principal_id

  credential {
    key   = "BaseAddress"
    value = "https://accounts.azuredatabricks.net/api/2.0/accounts/${var.DATABRICKS_ACCOUNT_ID}/scim/v2"
  }

  credential {
    key   = "SecretToken"
    value = var.DATABRICKS_ACCOUNT_SCIM_TOKEN
  }

  credential {
    key   = "SyncAll"
    value = "false"
  }
}

resource "azuread_synchronization_job" "this" {
  provider   = azuread.tokengen
  depends_on = [ azuread_synchronization_secret.this ]
  
  service_principal_id = module.azure_service_account.service_principal_id
  template_id          = "dataBricks"
  enabled              = true
}