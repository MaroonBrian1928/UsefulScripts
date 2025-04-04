# -----------------------------
# User Variables (change these)
# -----------------------------
$sourceSubscriptionId = "SOURCE_SUBSCRIPTION_ID"
$targetSubscriptionId = "TARGET_SUBSCRIPTION_ID"
$sourceVaultName      = "SOURCE_KEYVAULT_NAME"
$targetVaultName      = "TARGET_KEYVAULT_NAME"

# How far out you want to set the expiration if the secret has none in the source
# 8766 hours ~= 1 year
$hoursUntilExpiry     = 8766

# Rotation policy: rotate 30 days before expiry
$timeBeforeExpiry     = "P30D"

# -----------------------------
# Script Start
# -----------------------------

Write-Host "1) Logging in and switching to source subscription..."
az account set --subscription $sourceSubscriptionId

Write-Host "2) Retrieving list of secrets from source vault: $sourceVaultName"
$secrets = az keyvault secret list --vault-name $sourceVaultName | ConvertFrom-Json

# Collect details for each secret (including the value and existing attributes)
$secretDetailsArray = @()
foreach ($secret in $secrets) {
    $secretName = $secret.name
    Write-Host "   - Fetching full details for secret: $secretName"
    
    $secretDetail = az keyvault secret show `
        --vault-name $sourceVaultName `
        --name $secretName `
        | ConvertFrom-Json
    
    $secretDetailsArray += $secretDetail
}

Write-Host "3) Switching context to target subscription..."
az account set --subscription $targetSubscriptionId

Write-Host "4) Migrating secrets to target vault: $targetVaultName"
foreach ($secretDetail in $secretDetailsArray) {
    $secretName  = $secretDetail.name
    $secretValue = $secretDetail.value
    
    # Check if the secret has an expiration date; if so, convert it to the required UTC format.
    if ($secretDetail.attributes.expires) {
        $expirationDate = [datetime]::Parse($secretDetail.attributes.expires).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
    }
    else {
        $expirationDate = (Get-Date).AddHours($hoursUntilExpiry).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
    }

    Write-Host "`n--- Migrating secret: $secretName ---"
    Write-Host "   Setting secret value and expiration date: $expirationDate"

    # Create/Update the secret in the target vault
    if ($secretDetail.contentType) {
        az keyvault secret set `
            --vault-name $targetVaultName `
            --name $secretName `
            --value $secretValue `
            --content-type $secretDetail.contentType `
            --expires $expirationDate | Out-Null
    }
    else {
        az keyvault secret set `
            --vault-name $targetVaultName `
            --name $secretName `
            --value $secretValue `
            --expires $expirationDate | Out-Null
    }

    # -----------------------------
    # (Optional) Set a rotation policy
    # -----------------------------
    $policyJson = @"
{
  "lifetimeActions": [
    {
      "trigger": {
        "timeBeforeExpiry": "$timeBeforeExpiry"
      },
      "action": {
        "type": "Rotate"
      }
    }
  ],
  "attributes": {
    "expiryTime": "P1Y"
  }
}
"@

    Write-Host "   Applying rotation policy (rotate $timeBeforeExpiry before expiry)."
    az keyvault secret rotation-policy set `
        --vault-name $targetVaultName `
        --name $secretName `
        --value $policyJson | Out-Null
}

Write-Host "`nAll secrets have been migrated, and rotation policies have been applied."
