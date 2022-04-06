terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 2.26" 
    }
  }
}

provider "azurerm" {
    skip_provider_registration = true
    features {
      resource_group {
      prevent_deletion_if_contains_resources = false
    }
    }
}

resource "azurerm_resource_group" "apache_terraform_rg" {
  name     = "aulainfracloudterraform"
  location = "australiaeast"
}


resource "azurerm_virtual_network" "vnet-aulainfra" {
  name                = "vnet-aula"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  address_space       = ["10.0.0.0/16"]


  tags = {
    environment = "Production"
    faculdade = "Impacta"
    turma = "ES23"
  }
  
}

resource "azurerm_subnet" "subnet" {
  name                 = "apachetf_subnet"
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  resource_group_name  = azurerm_resource_group.apache_terraform_rg.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "ip-aulainfra" {
  name                = "ip-aula"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}


resource "azurerm_network_security_group" "nsg-aulainfra" {
  name                = "nsg-aula"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

   tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "apache_terraform_nic" {
  name                = "apachetf-nic2"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

  ip_configuration {
    name                          = "ip-aula-nic"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-aulainfra.id
  }
}


resource "azurerm_network_interface_security_group_association" "nic-nsg-aulainfra" {
  network_interface_id      = azurerm_network_interface.apache_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.nsg-aulainfra.id
}

resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "storageaccountmyvm10"
  resource_group_name      = azurerm_resource_group.apache_terraform_rg.name
  location                 = "australiaeast"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_machine" "vm-aulainfra" {
  name                = "vm-aula"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  vm_size             = "Standard_DS1_v2"

  network_interface_ids         = ["${azurerm_network_interface.apache_terraform_nic.id}"]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vmtf"
    admin_username = "michaelepmba"
    admin_password = "Maicon@01"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "staging"
  }

}

  data "azurerm_public_ip" "ip-aula" {
    name = azurerm_public_ip.ip-aulainfra.name
    resource_group_name = "aulainfracloudterraform"
  }

  resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = "michaelepmba"
    password = "Maicon@01"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-aulainfra
  ]
}

resource "null_resource" "upload-app" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = "michaelepmba"
    password = "Maicon@01"
  }

 provisioner "file" {
    source = "app"
    destination = "/home/testeadmin"
  }

  depends_on = [
    azurerm_virtual_machine.vm-aulainfra
  ]
}