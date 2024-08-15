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

# Review Testing Locally/ Troubleshooting steps if required
# before running dispatch workflow actions or tear down

act -j terraform-dispatch-test \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show) \
    --artifact-server-path /tmp/artifacts

act -j terraform-dispatch-destroy \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --var DATABRICKS_ADMINISTRATOR=$(git config user.email) \
    --remote-name $(git remote show)
```

### Local Testing

```
# Configure Databricks CLI
databricks configure \
  --profile AZURE_WORKSPACE \
  --host $(terraform -chdir=./test/databricks output -raw databricks_workspace_host) \
  --token <<EOF
  $(terraform -chdir=./test/databricks output -raw databricks_access_token)
EOF

export AZURE_CLIENT_ID=$(terraform -chdir=./test/service_account output -raw service_account_client_id)
export AZURE_CLIENT_SECRET=$(terraform -chdir=./test/service_account output -raw service_account_client_secret)
export AZURE_TENANT_ID=$(cat ~/creds/azure.secrets | grep -o '^AZURE_TENANT_ID=.*' | cut -f2 -d= )
export AZURE_KEYVAULT_NAME=$(terraform -chdir=./test/databricks output -raw azure_keyvault_name)
export SERVICE_ACCOUNT_KEY_NAME=$(terraform -chdir=./test/databricks output -raw azure_keyvault_secret_client_id_name)
export SERVICE_ACCOUNT_KEY_SECRET=$(terraform -chdir=./test/databricks output -raw azure_keyvault_secret_client_secret_name)
export DATABRICKS_CLUSTER_ID=$(terraform -chdir=./test/databricks output -json databricks_cluster_ids | jq -r '.[0]')
export OUTPUT_DIR=$(terraform -chdir=./test/databricks output -raw databricks_external_location_url)
export OUTPUT_TABLE=$(terraform -chdir=./test/databricks output -json databricks_unity_catalog_table_paths | jq -r '.[0]')
export EXAMPLE_HOLDING_FILE_PATH=$(terraform -chdir=./test/databricks output -raw databricks_example_holdings_data_path)
export EXAMPLE_WEATHER_FILE_PATH=$(terraform -chdir=./test/databricks output -raw databricks_example_weather_data_path)

# Initialize Databricks Asset Bundle
# DO NOT user hyphens "-" in project name - will cause package namespace to be broken in Python
echo "{
  \"project_name\": \"sim_parabales_dab_example\",
  \"distribution_list\": \"$(git config user.email)\",
  \"databricks_cli_profile\": \"AZURE_WORKSPACE\",
  \"databricks_cloud_provider\": \"AZURE\",
  \"databricks_service_account_key_name\": \"$SERVICE_ACCOUNT_KEY_NAME\",
  \"databricks_service_account_key_secret\": \"$SERVICE_ACCOUNT_KEY_SECRET\"
}" > databricks_dab_template_config

databricks bundle init https://github.com/sim-parables/databricks-xcloud-asset-bundle-template \
  --output-dir=dab_solution \
  --profile=AZURE_WORKSPACE \
  --config-file=databricks_dab_template_config

cd dab_solution
python3 run_local.py \
  --test_entrypoint="$(pwd)/tests/entrypoint.py" \
  --test_path="$(pwd)/tests/unit/local/test_examples.py" \
  --csv_path=https://duckdb.org/data/holdings.csv

python3 run_local.py \
  --test_entrypoint="$(pwd)/tests/entrypoint.py" \
  --test_path="$(pwd)/tests/integration/test_output.py" \
  --csv_path=https://duckdb.org/data/weather.csv

export $(cat .env)
python3 run_local.py \
  --test_entrypoint="$(pwd)/tests/entrypoint.py" \
  --test_path="$(pwd)/tests/integration/test_azure.py"

python3 run_local.py \
  --test_entrypoint="$(pwd)/tests/entrypoint.py" \
  --test_path="$(pwd)/tests/unit/local/test_examples.py" \
  --csv_path=https://duckdb.org/data/holdings.csv

python3 run_local.py \
  --test_entrypoint="$(pwd)/tests/entrypoint.py" \
  --test_path="$(pwd)/tests/integration/test_output.py" \
  --output_path=$OUTPUT_DIR

databricks bundle deploy \
  --var="databricks_cluster_id=$DATABRICKS_CLUSTER_ID,csv_holdings_path=$EXAMPLE_HOLDING_FILE_PATH,csv_weather_path=$EXAMPLE_WEATHER_FILE_PATH,output_path=$OUTPUT_DIR,output_table=$OUTPUT_TABLE" \
  --profile=AZURE_WORKSPACE

databricks bundle run sim_parabales_dab_example_example_unit_test \
  --var="databricks_cluster_id=$DATABRICKS_CLUSTER_ID,csv_holdings_path=$EXAMPLE_HOLDING_FILE_PATH,csv_weather_path=$EXAMPLE_WEATHER_FILE_PATH,output_path=$OUTPUT_DIR,output_table=$OUTPUT_TABLE" \
  --profile=AZURE_WORKSPACE

databricks bundle run sim_parabales_dab_example_example_integration_test \
  --var="databricks_cluster_id=$DATABRICKS_CLUSTER_ID,csv_holdings_path=$EXAMPLE_HOLDING_FILE_PATH,csv_weather_path=$EXAMPLE_WEATHER_FILE_PATH,output_path=$OUTPUT_DIR,output_table=$OUTPUT_TABLE" \
  --profile=AZURE_WORKSPACE

databricks bundle run sim_parabales_dab_example_example_output \
  --var="databricks_cluster_id=$DATABRICKS_CLUSTER_ID,csv_holdings_path=$EXAMPLE_HOLDING_FILE_PATH,csv_weather_path=$EXAMPLE_WEATHER_FILE_PATH,output_path=$OUTPUT_DIR,output_table=$OUTPUT_TABLE" \
  --profile=AZURE_WORKSPACE

databricks bundle run sim_parabales_dab_example_example_output_uc \
  --var="databricks_cluster_id=$DATABRICKS_CLUSTER_ID,csv_holdings_path=$EXAMPLE_HOLDING_FILE_PATH,csv_weather_path=$EXAMPLE_WEATHER_FILE_PATH,output_path=$OUTPUT_DIR,output_table=$OUTPUT_TABLE" \
  --profile=AZURE_WORKSPACE
```

### Unit Testing

```
act -j terraform-unit-tests \
    -e .github/local.json \
    --secret-file ~/creds/azure.secrets \
    --remote-name $(git remote show)
```