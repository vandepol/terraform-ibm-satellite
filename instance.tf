#####################################################
# IBM Cloud Satellite -  Azure Example
# Copyright 2021 IBM
#####################################################

/*
This template uses following
Modules:
  Azure/network-security-group/azurerm - Security group and Security group rules
  Azure/vnet/azurerm                   - vpc, subnets, Attach security group to subnets
Resources: (Using these resources because no standard azure module was found that meets our requirement)
  azurerm_resource_group                - Resource Group
  azurerm_network_interface             - Network interfaces for the Azure Instance
  azurerm_linux_virtual_machine         - Linux Virtual Machines, Attaches host to the Satellite location
*/


// Azure Resource Group
resource "azurerm_resource_group" "resource_group" {
  count    = var.is_az_resource_group_exist == false ? 1 : 0
  name     = var.az_resource_group
  location = var.az_region
}
data "azurerm_resource_group" "resource_group" {
  name       = var.is_az_resource_group_exist == false ? azurerm_resource_group.resource_group.0.name : var.az_resource_group
  depends_on = [azurerm_resource_group.resource_group]
}


//Module to create security group and security group rules
module "network-security-group" {
  source                = "Azure/network-security-group/azurerm"
  resource_group_name   = data.azurerm_resource_group.resource_group.name
  location              = data.azurerm_resource_group.resource_group.location # Optional; if not provided, will use Resource Group location
  security_group_name   = "${var.az_resource_prefix}-sg"
  source_address_prefix = ["*"]
  custom_rules = [
    {
      name                       = "ssh"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "description-myssh"
    },
    {
      name                       = "satellite"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "80,443,30000-32767"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "description-http"
    },
  ]
  tags = {
    ibm-satellite = var.az_resource_prefix
  }
  depends_on = [data.azurerm_resource_group.resource_group]
}


locals {
  zones = [1, 2, 3]
}

# module to create vpc, subnets and attach security group to subnet
module "vnet" {
  depends_on          = [data.azurerm_resource_group.resource_group]
  source              = "Azure/vnet/azurerm"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  vnet_name           = "${var.az_vpc}"
  address_space       = ["10.0.0.0/16"] 
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names        = ["${var.az_resource_prefix}-subnet", "${var.az_worker_resource_prefix}-subnet"]
  
  nsg_ids = {
    "${var.az_resource_prefix}-subnet" = module.network-security-group.network_security_group_id
    "${var.az_worker_resource_prefix}-subnet" = module.network-security-group.network_security_group_id
  }

  tags = {
    ibm-satellite = var.az_resource_prefix  
  }
}

// Creates network interface for the subnets that are been created
resource "azurerm_network_interface" "az_nic" {
  depends_on          = [data.azurerm_resource_group.resource_group]
  count               = var.satellite_host_count
  name                = "${var.az_resource_prefix}-nic-${count.index}"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location

  ip_configuration {
    name                          = "${var.az_resource_prefix}-nic-internal"
    subnet_id                     = element(module.vnet.vnet_subnets, 0)
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
  tags = {
    ibm-satellite = var.az_resource_prefix
  }
}

// Creates network interface for the subnets that are been created
resource "azurerm_network_interface" "az_worker_nic" {
  depends_on          = [data.azurerm_resource_group.resource_group]
  count               = var.addl_host_count
  name                = "${var.az_worker_resource_prefix}-nic-worker-${count.index}"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = data.azurerm_resource_group.resource_group.location

  ip_configuration {
    name                          = "${var.az_worker_resource_prefix}-nic-internal"
    subnet_id                     = element(module.vnet.vnet_subnets, 1)
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
  tags = {
    ibm-satellite = var.az_worker_resource_prefix
  }
}


resource "tls_private_key" "rsa_key" {
  count     = (var.ssh_public_key == null ? 1 : 0)
  algorithm = "RSA"
  rsa_bits  = 4096
}

// Creates Linux Virtual Machines and attaches host to the location..
resource "azurerm_linux_virtual_machine" "az_host" {
  depends_on            = [data.azurerm_resource_group.resource_group, module.satellite-location]
  count                 = var.satellite_host_count
  name                  = "${var.az_resource_prefix}-vm-${count.index}"
  resource_group_name   = data.azurerm_resource_group.resource_group.name
  location              = data.azurerm_resource_group.resource_group.location
  size                  = var.instance_type
  admin_username        = "adminuser"
  custom_data           = base64encode(module.satellite-location.host_script)
  network_interface_ids = [azurerm_network_interface.az_nic[count.index].id]

  zone = element(local.zones, count.index)
  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key != null ? var.ssh_public_key : tls_private_key.rsa_key.0.public_key_openssh
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7-LVM"
    version   = "latest"
  }
}

// Creates Linux Virtual Machines and attaches host to the location..
resource "azurerm_linux_virtual_machine" "az_worker_host" {
  depends_on            = [data.azurerm_resource_group.resource_group, module.satellite-location]
  count                 = var.addl_host_count
  name                  = "${var.az_worker_resource_prefix}-vm-${count.index}"
  resource_group_name   = data.azurerm_resource_group.resource_group.name
  location              = data.azurerm_resource_group.resource_group.location
  size                  = var.worker_instance_type
  admin_username        = "adminuser"
  custom_data           = base64encode(module.satellite-location.host_script)
  network_interface_ids = [azurerm_network_interface.az_worker_nic[count.index].id]

  zone = element(local.zones, count.index)
  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key != null ? var.ssh_public_key : tls_private_key.rsa_key.0.public_key_openssh
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7-LVM"
    version   = "latest"
  }
}






resource "azurerm_managed_disk" "data_disk" {
  count                = var.satellite_host_count
  name                 = "${var.az_resource_prefix}-disk-${count.index}"
  location             = data.azurerm_resource_group.resource_group.location
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

}

resource "azurerm_managed_disk" "data_worker_disk" {
  count                = var.addl_host_count
  name                 = "${var.az_worker_resource_prefix}-disk-${count.index}"
  location             = data.azurerm_resource_group.resource_group.location
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

}

resource "azurerm_virtual_machine_data_disk_attachment" "disk_attach" {
  count              = var.satellite_host_count
  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.az_host[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk_worker_attach" {
  count              = var.addl_host_count
  managed_disk_id    = azurerm_managed_disk.data_worker_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.az_worker_host[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}
