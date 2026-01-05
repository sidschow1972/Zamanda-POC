variable "location" {
  type    = string
  default = "eastus"
}
variable "prefix" {
  type    = string
  default = "zammadpoc"
}

# Passed from GitHub Actions
variable "image" { type = string } # ex: acrname.azurecr.io/app:<sha>


resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 

# resource "azurerm_container_app_environment" "cae" {
#   name                       = "cae-${var.prefix}"
#   location                   = azurerm_resource_group.rg.location
#   resource_group_name        = azurerm_resource_group.rg.name
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
# }

# resource "azurerm_container_app" "app" {
#   name                         = "ca-${var.prefix}"
#   container_app_environment_id = azurerm_container_app_environment.cae.id
#   resource_group_name          = azurerm_resource_group.rg.name
#   revision_mode                = "Single"

#   ingress {
#     external_enabled = true
#     target_port      = 8080
#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }

#   template {
#     container {
#       name   = "app"
#       image  = var.image
#       cpu    = 0.5
#       memory = "1Gi"
#     }
#   }
# }
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-${var.prefix}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}
# Public IP resource details are in the azurerm docs. :contentReference[oaicite:2]{index=2}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# NSG resource is documented here. :contentReference[oaicite:3]{index=3}

# Allow SSH 22
resource "azurerm_network_security_rule" "ssh" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Allow HTTP 80 (optional; for production you’d normally terminate TLS and restrict this)
resource "azurerm_network_security_rule" "http" {
  name                        = "Allow-HTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Allow HTTPS 443
resource "azurerm_network_security_rule" "https" {
  name                        = "Allow-HTTPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Associate NSG to NIC (so rules apply)
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.prefix}-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  disable_password_authentication = false
   custom_data = base64encode(
   file("${path.module}/../docker/cloud-init.yaml")
 )
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
#   lifecycle {
#     prevent_destroy = true
#     ignore_changes = [ custom_data ]
#   }
}
resource "azurerm_virtual_machine_extension" "deploy_zammad" {
  name               = "deploy-zammad"
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  publisher          = "Microsoft.Azure.Extensions"
  type               = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = "bash bootstrap.sh"
  })

  protected_settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/sidschow1972/Zamanda-POC/main/docker/bootstrap.sh",
      "https://raw.githubusercontent.com/sidschow1972/Zamanda-POC/main/docker/docker-compose.yaml"
    ]
  })
}

