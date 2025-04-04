#!/bin/bash
# This script migrates secrets from a source Azure Key Vault to a target Key Vault
# across different subscriptions using Azure CLI.

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq and try again."
    exit 1
fi

# Variables - replace these with your actual values
sourceSubscriptionId="SOURCE_SUBSCRIPTION_ID"
targetSubscriptionId="TARGET_SUBSCRIPTION_ID"
sourceVaultName="SOURCE_KEYVAULT_NAME"
targetVaultName="TARGET_KEYVAULT_NAME"

echo "Setting context to source subscription: $sourceSubscriptionId"
az account set --subscription "$sourceSubscriptionId"

echo "Retrieving secrets from vault: $sourceVaultName"
# Retrieve the list of secrets (JSON output)
secretsList=$(az keyvault secret list --vault-name "$sourceVaultName" --output json)

# Initialize an array to hold each secret's full details (as JSON)
secretDetails=()

# Loop through each secret name in the list
secretNames=$(echo "$secretsList" | jq -r '.[].name')
for secretName in $secretNames; do
    echo "Fetching details for secret: $secretName"
    secretDetail=$(az keyvault secret show --vault-name "$sourceVaultName" --name "$secretName" --output json)
    secretDetails+=("$secretDetail")
done

# Combine all secret details into a single JSON array
allSecretsJson=$(printf '%s\n' "${secretDetails[@]}" | jq -s '.')

echo "Switching context to target subscription: $targetSubscriptionId"
az account set --subscription "$targetSubscriptionId"

echo "Migrating secrets to vault: $targetVaultName"
# Iterate over each secret in the JSON array and set it in the target vault
echo "$allSecretsJson" | jq -c '.[]' | while read secret; do
    name=$(echo "$secret" | jq -r '.name')
    value=$(echo "$secret" | jq -r '.value')
    contentType=$(echo "$secret" | jq -r '.contentType')

    echo "Migrating secret: $name"
    if [ "$contentType" != "null" ]; then
        az keyvault secret set --vault-name "$targetVaultName" --name "$name" --value "$value" --description "$contentType"
    else
        az keyvault secret set --vault-name "$targetVaultName" --name "$name" --value "$value"
    fi
done

echo "Migration complete!"
