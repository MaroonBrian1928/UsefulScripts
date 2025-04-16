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


### v2

#!/bin/bash

# Config
account_name="<your-storage-account>"
resource_type="file"  # set to "file" or "blob"
container_name="<your-container-name>"
share_name="<your-file-share-name>"

# Get free disk space in MB and subtract 100 MB buffer
free_space=$(df -m / | awk 'NR==2 {print $4}')
buffered_space=$((free_space - 100))

if [ "$resource_type" = "blob" ]; then
  echo "Checking Blob container size..."

  container_size=$(az storage blob list \
    --account-name "$account_name" \
    --container-name "$container_name" \
    --auth-mode login \
    --query "[].properties.contentLength" \
    --output tsv | \
    awk '{s+=$1} END {print int(s/1024/1024)}')

elif [ "$resource_type" = "file" ]; then
  echo "Checking File share size..."

  file_sizes=$(az storage file list \
    --account-name "$account_name" \
    --share-name "$share_name" \
    --auth-mode login \
    --output json | \
    jq '[.[] | select(.properties.contentLength != null) | .properties.contentLength] | add')

  file_sizes=${file_sizes:-0}
  container_size=$((file_sizes / 1024 / 1024))

else
  echo "Invalid resource_type: must be 'blob' or 'file'"
  exit 1
fi

# Compare available space with remote size
if [ "$buffered_space" -gt "$container_size" ]; then
  echo "Enough space with 100MB buffer. Proceeding..."
  # your logic here
else
  echo "Not enough space (100MB buffer included). Exiting."
  exit 1
fi
