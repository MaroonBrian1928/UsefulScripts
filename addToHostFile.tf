locals {
  vm_entries = [
    for vm in module.windowsvms :
    { ip = vm.ip_address, name = vm.name }
  ]
}

resource "azurerm_virtual_machine_run_command" "update_hosts" {
  for_each           = module.windowsvms
  name               = "add-to-hosts-${each.key}"
  virtual_machine_id = each.value.id
  run_as_user        = "System"

  source {
    script = <<-EOF
# Parse our HCL-generated JSON into a PS array of objects
$entries = '${jsonencode(local.vm_entries)}' | ConvertFrom-Json

foreach ($e in $entries) {
  $ip       = $e.ip
  $hostname = $e.name
  $pattern  = "^\s*$ip\s+$hostname$"
  if (-not (Select-String -Path "C:\\Windows\\System32\\drivers\\etc\\hosts" `
                        -Pattern $pattern -Quiet)) {
    Add-Content -Path "C:\\Windows\\System32\\drivers\\etc\\hosts" `
                -Value "$ip`t$hostname"
  }
}
EOF
  }
}

##
## Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry'
## Get-Service RemoteRegistry

Get-WinEvent -LogName System -MaxEvents 100 |
Where-Object { $_.Id -eq 7036 -and $_.Message -like "*Remote Registry*" } |
Select-Object TimeCreated, Message | Format-Table -AutoSize

Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4688)]]" |
Where-Object { $_.Message -match "sc\.exe|powershell|Stop-Service" } |
Select-Object TimeCreated, Message | Format-Table -Wrap

Get-ScheduledTask | Where-Object { $_.Actions -match "Stop-Service|RemoteRegistry" }

Get-DscConfigurationStatus
Get-DscLocalConfigurationManager

Get-Service WindowsAzureGuestAgent
Get-ChildItem "C:\Packages\Plugins" | Select Name

gpresult /h C:\gp.html
Start-Process "C:\gp.html"

gpresult /h C:\gp.html; (Get-Content C:\gp.html -Raw) -replace '<[^>]+>', '' | Out-String


# 1. List all attached disks and identify uninitialized (RAW) ones:
Get-Disk | Where-Object PartitionStyle -Eq 'RAW'

# 2. For each RAW disk, bring it online, initialize, partition, format, and assign a drive letter:
$raw = Get-Disk | Where-Object PartitionStyle -Eq 'RAW'
foreach ($disk in $raw) {
    # a) Bring online and clear read-only if set
    Set-Disk   -Number $disk.Number -IsOffline:$false -IsReadOnly:$false

    # b) Initialize with GPT partition style
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru |

      # c) Create a single full-size partition and assign next available drive letter
      New-Partition -UseMaximumSize -AssignDriveLetter |

      # d) Format it as NTFS without prompt
      Format-Volume -FileSystem NTFS -NewFileSystemLabel "DataDisk$($disk.Number)" -Confirm:$false
}

Start-Process -FilePath 'C:\path\to\your-script.bat' -Wait -NoNewWindow


az vm run-command invoke `
  --resource-group "" `
  --name "" `
  --subscription "" `
  --command-id RunPowerShellScript `
  --scripts 'Get-Disk | Where-Object PartitionStyle -eq "RAW" | ForEach-Object { 
      Set-Disk -Number $_.Number -IsOffline $false; 
      Set-Disk -Number $_.Number -IsReadOnly $false; 
      $p = Initialize-Disk -Number $_.Number -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter; 
      Format-Volume -DriveLetter $p.DriveLetter -FileSystem NTFS -NewFileSystemLabel "DataDisk$($_.Number)" -Confirm:$false 
  }'


terraform import \
  'module.db_windows_vms["0"].azurerm_virtual_machine_data_disk_attachment.disks_attachment["disk1"]' \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Compute/virtualMachines/<VM_NAME>/dataDisks/<DISK_NAME>


# Get any Database Engine service (default = MSSQLSERVER, named = MSSQL$InstanceName)
$sqlServices = Get-Service |
    Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' }

if ($sqlServices) {
    Write-Host 'sql installed'
} else {
    Write-Host 'heck its not on here'
}
