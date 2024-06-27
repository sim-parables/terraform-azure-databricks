# Github Action Workflows

[Github Actions](https://docs.github.com/en/actions) to automate, customize, and execute your software development workflows coupled with the repository.

## Local Actions

Validate Github Workflows locally with [Nekto's Act](https://nektosact.com/introduction.html). More info found in the Github Repo [https://github.com/nektos/act](https://github.com/nektos/act).

### Prerequisits

Store the identical Secrets in Github Organization/Repository to local workstation

```
cat <<EOF > ~/creds/azure.secrets
# Terraform.io Token
TF_API_TOKEN=[COPY/PASTE MANUALLY]

# Github PAT
GITHUB_TOKEN=$(gh auth token)

# Azure
AZURE_TENANT_ID=$(az account list | jq -r '.[].tenantId')
AZURE_SUBSCRIPTION_ID=$(az account list | jq -r '.[].id')
AZURE_CLIENT_ID=[COPY/PASTE MANUALLY]
AZURE_CLIENT_SECRET=[COPY/PASTE MANUALLY]
AZURE_DATABRICKS_ACCOUNT_ID=[COPY/PASTE MANUALLY]
AZURE_DATABRICKS_ACCOUNT_CLIENT_ID=[COPY/PASTE MANUALLY]
AZURE_DATABRICKS_ACCOUNT_CLIENT_SECRET=[COPY/PASTE MANUALLY]
AZURE_DATABRICKS_ACCOUNT_SCIM_TOKEN=[COPY/PASTE MANUALLY]
EOF
```

### Manual Dispatch Testing

```
# Try the Terraform Read job first
act -j terraform-dispatch-plan \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show)

act -j terraform-dispatch-apply \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show)

act -j terraform-dispatch-test \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show)

act -j terraform-dispatch-destroy \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show)
```

### Integration Testing

```
# Create an artifact location to upload/download between steps locally
mkdir /tmp/artifacts

# Run the full Integration test with
act -j terraform-integration-destroy \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show) \
    --artifact-server-path /tmp/artifacts
```

### Unit Testing

```
act -j terraform-unit-tests \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --remote-name $(git remote show)
```