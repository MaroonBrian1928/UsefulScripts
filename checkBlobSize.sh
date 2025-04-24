#!/bin/bash

# Required variables
ACCOUNT_NAME="your_storage_account"
CONTAINER_NAME="your_container"
AUTH_MODE="login"  # or "key"
RESOURCE_GROUP="your_resource_group"  # Only needed for login-based access

# Initialize
marker=""
total_size=0

while : ; do
  # Fetch blobs (with pagination)
  result=$(az storage blob list \
    --account-name "$ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --auth-mode "$AUTH_MODE" \
    --marker "$marker" \
    --num-results 5000 \
    --query "[].properties.contentLength" \
    --output tsv)

  # Sum current page
  while read -r size; do
    [[ -n "$size" ]] && total_size=$((total_size + size))
  done <<< "$result"

  # Get next marker to continue
  marker=$(az storage blob list \
    --account-name "$ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --auth-mode "$AUTH_MODE" \
    --marker "$marker" \
    --num-results 5000 \
    --query "nextMarker" \
    --output tsv)

  # Exit when there’s no more data
  [[ -z "$marker" ]] && break
done

# Convert and display size
size_mb=$(awk "BEGIN {printf \"%.2f\", $total_size / 1024 / 1024}")
echo "Total container size: $size_mb MB"
