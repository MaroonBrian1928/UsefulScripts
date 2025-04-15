#!/bin/bash

# Get free space on root (in MB)
free_space=$(df -m / | awk 'NR==2 {print $4}')

# Subtract 100 MB as a buffer
buffered_space=$((free_space - 100))

# Get container size in MB (rounded down to integer)
container_size=$(az storage blob list \
  --account-name <account-name> \
  --container-name <container-name> \
  --auth-mode login \
  --query "[].properties.contentLength" \
  --output tsv | \
  awk '{s+=$1} END {print int(s/1024/1024)}')

# Compare
if [ "$buffered_space" -gt "$container_size" ]; then
  echo "Enough space with 100MB buffer. Proceeding..."
  # Your commands here
else
  echo "Not enough space (100MB buffer included). Exiting."
  exit 1
fi
