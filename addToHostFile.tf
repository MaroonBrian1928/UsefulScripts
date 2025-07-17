variable "custom_hostname" {
  type        = string
  description = "The hostname to map to the IP"
}

module "my_module" {
  source = "./module"
  # ...
}

resource "azurerm_virtual_machine_run_command" "update_hosts" {
  name               = "add-to-hosts"
  virtual_machine_id = azurerm_windows_virtual_machine.my_vm.id
  run_as_user        = "System"

  lifecycle {
    ignore_changes = [
      # Prevent constant re-application
      run_as_user,
      source,
      script_content,
    ]
  }

  script_content = <<-EOF
    $ip = "${module.my_module.my_ip_output}"
    $hostname = "${var.custom_hostname}"
    $entry = "$ip`t$hostname"
    Add-Content -Path "C:\\Windows\\System32\\drivers\\etc\\hosts" -Value $entry
  EOF
}
