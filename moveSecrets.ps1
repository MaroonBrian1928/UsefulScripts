# Define variables for source and target subscriptions and vault names
$sourceSubscriptionId = "SOURCE_SUBSCRIPTION_ID"
$targetSubscriptionId = "TARGET_SUBSCRIPTION_ID"
$sourceVaultName      = "SOURCE_KEYVAULT_NAME"
$targetVaultName      = "TARGET_KEYVAULT_NAME"

# Set the Azure context to the source subscription
Write-Host "Setting context to source subscription: $sourceSubscriptionId"
az account set --subscription $sourceSubscriptionId

# Retrieve the list of secrets from the source Key Vault
Write-Host "Retrieving secrets from vault: $sourceVaultName"
$secrets = az keyvault secret list --vault-name $sourceVaultName | ConvertFrom-Json

# Initialize an array to hold the detailed information of each secret
$secretDetailsArray = @()

foreach ($secret in $secrets) {
    $secretName = $secret.name
    Write-Host "Fetching details for secret: $secretName"
    $secretDetail = az keyvault secret show --vault-name $sourceVaultName --name $secretName | ConvertFrom-Json
    $secretDetailsArray += $secretDetail
}

# Set the Azure context to the target subscription
Write-Host "Switching context to target subscription: $targetSubscriptionId"
az account set --subscription $targetSubscriptionId

# Migrate each secret to the target Key Vault
foreach ($secretDetail in $secretDetailsArray) {
    $secretName  = $secretDetail.name
    $secretValue = $secretDetail.value
    Write-Host "Migrating secret: $secretName"
    
    # Optionally, include contentType as a description (if available)
    if ($secretDetail.contentType) {
        az keyvault secret set `
            --vault-name $targetVaultName `
            --name $secretName `
            --value $secretValue `
            --description $secretDetail.contentType
    }
    else {
        az keyvault secret set `
            --vault-name $targetVaultName `
            --name $secretName `
            --value $secretValue
    }
}

Write-Host "Migration complete!"
