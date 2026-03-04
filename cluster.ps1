# List IP Address resources so you can pick the exact one
Get-ClusterResource | Where-Object ResourceType -eq "IP Address" | Format-Table Name, OwnerGroup, State

# Replace with your listener IP resource name
$ipRes = "IP Address (YourListenerName)"

# Set probe port to 59999
Get-ClusterResource $ipRes | Set-ClusterParameter -Name ProbePort -Value 59999

# Bounce it to apply
Stop-ClusterResource $ipRes
Start-ClusterResource $ipRes
