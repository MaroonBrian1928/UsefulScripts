resource "azurerm_virtual_machine_run_command" "update_hosts" {
  for_each           = module.windowsvms
  name               = "add-to-hosts-${each.key}"
  virtual_machine_id = each.value.id
  run_as_user        = "System"
  timeout_in_seconds = 600

  source {
    script = <<-EOF
      # Build an array of all VM IP/host pairs
      $entries = @(
%{ for vm_key, vm in module.windowsvms }
        @{ ip = "${vm.ip_address}"; name = "${vm.name}" },
%{ endfor }
      )

      # For each entry, append to hosts if missing
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
