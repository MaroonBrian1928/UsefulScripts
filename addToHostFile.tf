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
