# This block defines out resource group
resource "azurerm_resource_group" "Infinion_RG" {
  name     = "Infinion_RG"
  location = local.location
}

#This cloudinit block runs the nginx web server when the VM launches
data "cloudinit_config" "nginxconfig" {
  gzip          = true
  base64_encode = true

  part {
    content_type  = "text/cloud-config"
    content = "packages: ['nginx'] "
  }
}

#Creation of the VNet
resource "azurerm_virtual_network" "Infinion_VNet" {
  name                = "Infinion_VNet"
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/24"]

    depends_on = [ azurerm_resource_group.Infinion_RG ]
}
#This block creates the Subnet
resource "azurerm_subnet" "Infinion_Subnet" {
  name                 = "Infinion_Subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = "Infinion_VNet"
  address_prefixes     = ["10.0.0.0/28"]

    depends_on = [ azurerm_virtual_network.Infinion_VNet ]
}

#This block creates the Network Interface that will be linked to our public IP address
resource "azurerm_network_interface" "InfinionNIC" {
  name                = "Infinion_NIC"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Infinion_Subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.Infinion_IP.id
  }
  depends_on = [ azurerm_subnet.Infinion_Subnet ]
}

#Creation of the IP address
resource "azurerm_public_ip" "Infinion_IP" {
  name                = "Infinion_IP"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"

    depends_on = [ azurerm_resource_group.Infinion_RG ]
 
}

#Network Security Group that allows HTTP and SSH
resource "azurerm_network_security_group" "Infinion_NSG" {
  name                = "Infinion_NSG"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 700
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    depends_on = [ azurerm_resource_group.Infinion_RG ]
}

#This block links the Subnet to the Network Security Group
resource "azurerm_subnet_network_security_group_association" "Infinion_Subnet_NSG_Link" {
  subnet_id                 = azurerm_subnet.Infinion_Subnet.id
  network_security_group_id = azurerm_network_security_group.Infinion_NSG.id
}

#Creation of the Virtual Machine
resource "azurerm_linux_virtual_machine" "LinuxVM" {
  name                = "LinuxInfinionVM"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "daniel"
  custom_data = data.cloudinit_config.nginxconfig.rendered
  network_interface_ids = [ azurerm_network_interface.InfinionNIC.id ]

  admin_ssh_key {
    username   = "daniel"
    public_key = file("~/.ssh/terra.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  depends_on = [ azurerm_network_interface.InfinionNIC, azurerm_resource_group.Infinion_RG ]
}

#Date for IP address output
data "azurerm_public_ip" "Infinion_IP" {
  name                = azurerm_public_ip.Infinion_IP.name
  resource_group_name = local.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.Infinion_IP
}
