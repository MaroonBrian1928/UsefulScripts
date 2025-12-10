# 80, 443 outbound – Redis dependencies on Storage, PKI (internet),
# OS, infrastructure, antivirus (Remote IP = *)
resource "azurerm_network_security_rule" "redis_out_http_https_deps_any" {
  name                        = "out-redis-http-https-deps-any"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Redis deps on Storage/PKI/OS/AV per VNet doc"
}

# 443 outbound – Azure Key Vault + Azure Monitor (service tags)
resource "azurerm_network_security_rule" "redis_out_https_keyvault_azuremonitor" {
  name                        = "out-redis-https-keyvault-azuremonitor"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefixes = [
    "AzureKeyVault",
    "AzureMonitor",
  ]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Redis deps on AzureKeyVault & AzureMonitor"
}

# 12000 outbound – Azure Monitor
resource "azurerm_network_security_rule" "redis_out_tcp_12000_azuremonitor" {
  name                        = "out-redis-tcp-12000-azuremonitor"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "12000"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Redis dep on Azure Monitor TCP 12000"
}

# 53 outbound – DNS (TCP)
resource "azurerm_network_security_rule" "redis_out_dns_tcp" {
  name        = "out-redis-dns-tcp"
  priority    = 130
  direction   = "Outbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "DNS TCP to Azure DNS + custom for Redis subnet"

  source_port_range  = "*"
  destination_port_range = "53"
  source_address_prefix  = "VirtualNetwork"

  destination_address_prefixes = concat(
    [
      "168.63.129.16",
      "169.254.169.254",
    ],
    var.custom_dns_servers
  )

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 53 outbound – DNS (UDP)
resource "azurerm_network_security_rule" "redis_out_dns_udp" {
  name        = "out-redis-dns-udp"
  priority    = 140
  direction   = "Outbound"
  access      = "Allow"
  protocol    = "Udp"
  description = "DNS UDP to Azure DNS + custom for Redis subnet"

  source_port_range  = "*"
  destination_port_range = "53"
  source_address_prefix  = "VirtualNetwork"

  destination_address_prefixes = concat(
    [
      "168.63.129.16",
      "169.254.169.254",
    ],
    var.custom_dns_servers
  )

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 123 outbound – NTP
resource "azurerm_network_security_rule" "redis_out_ntp_123" {
  name                        = "out-redis-ntp-123"
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "OS NTP dependency"
}

# 1688 outbound – KMS activation
resource "azurerm_network_security_rule" "redis_out_kms_1688" {
  name                        = "out-redis-kms-1688"
  priority                    = 160
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1688"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "OS activation (KMS)"
}

# 8443 outbound – internal Redis (Redis subnet -> Redis subnet)
resource "azurerm_network_security_rule" "redis_out_internal_8443" {
  name                        = "out-redis-internal-8443"
  priority                    = 170
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 8443"
}

# 10221-10231 outbound – internal Redis
resource "azurerm_network_security_rule" "redis_out_internal_10221_10231" {
  name                        = "out-redis-internal-10221-10231"
  priority                    = 180
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10221-10231"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 10221-10231"
}

# 20226 outbound – internal Redis
resource "azurerm_network_security_rule" "redis_out_internal_20226" {
  name                        = "out-redis-internal-20226"
  priority                    = 190
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "20226"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 20226"
}

# 13000-13999 outbound – internal Redis
resource "azurerm_network_security_rule" "redis_out_internal_13000_13999" {
  name                        = "out-redis-internal-13000-13999"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "13000-13999"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 13000-13999"
}

# 15000-15999 outbound – internal + geo-replication (Redis subnet + geo peers)
resource "azurerm_network_security_rule" "redis_out_geo_15000_15999" {
  name        = "out-redis-geo-15000-15999"
  priority    = 210
  direction   = "Outbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "Internal + geo-replication 15000-15999"

  source_port_range     = "*"
  destination_port_range = "15000-15999"
  source_address_prefix = "VirtualNetwork"

  destination_address_prefixes = concat(
    ["VirtualNetwork"],
    var.geo_replica_peer_subnet_prefixes
  )

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 6379-6380 outbound – internal Redis
resource "azurerm_network_security_rule" "redis_out_internal_6379_6380" {
  name                        = "out-redis-internal-6379-6380"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6379-6380"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 6379-6380"
}

# 6379, 6380 inbound – client comms, Redis subnet, Azure LB
resource "azurerm_network_security_rule" "redis_in_client_6379_6380" {
  name        = "in-redis-client-6379-6380"
  priority    = 300
  direction   = "Inbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "Client + LB to Redis 6379/6380"

  source_port_range       = "*"
  destination_port_ranges = ["6379", "6380"]

  source_address_prefixes = concat(
    ["VirtualNetwork", "AzureLoadBalancer"],
    var.client_subnet_prefixes
  )

  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 8443 inbound – internal Redis only
resource "azurerm_network_security_rule" "redis_in_internal_8443" {
  name                        = "in-redis-internal-8443"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 8443"
}

# 8500 inbound – Azure LB (TCP)
resource "azurerm_network_security_rule" "redis_in_lb_8500_tcp" {
  name                        = "in-redis-lb-8500-tcp"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8500"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Azure LB 8500 TCP"
}

# 8500 inbound – Azure LB (UDP)
resource "azurerm_network_security_rule" "redis_in_lb_8500_udp" {
  name                        = "in-redis-lb-8500-udp"
  priority                    = 321
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "8500"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Azure LB 8500 UDP"
}

# 10221-10231 inbound – client + internal + LB
resource "azurerm_network_security_rule" "redis_in_client_internal_10221_10231" {
  name        = "in-redis-client-internal-10221-10231"
  priority    = 330
  direction   = "Inbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "Redis cluster client + internal + LB 10221-10231"

  source_port_range      = "*"
  destination_port_range = "10221-10231"

  source_address_prefixes = concat(
    ["VirtualNetwork", "AzureLoadBalancer"],
    var.client_subnet_prefixes
  )

  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 13000-13999 inbound – client + internal + LB
resource "azurerm_network_security_rule" "redis_in_client_internal_13000_13999" {
  name        = "in-redis-client-internal-13000-13999"
  priority    = 340
  direction   = "Inbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "Redis cluster client + LB 13000-13999"

  source_port_range      = "*"
  destination_port_range = "13000-13999"

  source_address_prefixes = concat(
    ["VirtualNetwork", "AzureLoadBalancer"],
    var.client_subnet_prefixes
  )

  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 15000-15999 inbound – client + internal + LB + geo-replica peers
resource "azurerm_network_security_rule" "redis_in_client_geo_15000_15999" {
  name        = "in-redis-client-geo-15000-15999"
  priority    = 350
  direction   = "Inbound"
  access      = "Allow"
  protocol    = "Tcp"
  description = "Redis cluster client + LB + geo-rep 15000-15999"

  source_port_range      = "*"
  destination_port_range = "15000-15999"

  source_address_prefixes = concat(
    ["VirtualNetwork", "AzureLoadBalancer"],
    var.client_subnet_prefixes,
    var.geo_replica_peer_subnet_prefixes
  )

  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
}

# 16001 inbound – Azure LB (TCP)
resource "azurerm_network_security_rule" "redis_in_lb_16001_tcp" {
  name                        = "in-redis-lb-16001-tcp"
  priority                    = 360
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "16001"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Azure LB 16001 TCP"
}

# 16001 inbound – Azure LB (UDP)
resource "azurerm_network_security_rule" "redis_in_lb_16001_udp" {
  name                        = "in-redis-lb-16001-udp"
  priority                    = 361
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "16001"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Azure LB 16001 UDP"
}

# 20226 inbound – internal Redis only
resource "azurerm_network_security_rule" "redis_in_internal_20226" {
  name                        = "in-redis-internal-20226"
  priority                    = 370
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "20226"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis.name
  description                 = "Internal Redis communications 20226"
}
