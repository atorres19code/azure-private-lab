terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

#
# Azure Lab Configuration
# Deploys an App Service accessible only from a private network
#
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-private-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-app-service"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_app_service_plan" "asp" {
  name                = "asp-private-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "app_service" {
  name                = "private-webapp-${random_string.random.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
  site_config {
    linux_fx_version = "NODE|18-lts"
  }
  https_only = true
}

resource "azurerm_private_endpoint" "private_endpoint" {
  name                = "pep-app-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id

  # Connection to the App Service
  private_service_connection {
    name                           = "app-service-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_app_service.app_service.id
    subresource_names              = ["sites"]
  }

  # Explicit dependency to ensure the App Service is created first
  depends_on = [azurerm_app_service.app_service]
}

# Private DNS zone is required for the VNet to resolve the App Service's FQDN to its private IP
resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name

  # Explicit dependency on the Resource Group creation
  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_private_dns_a_record" "dns_a_record" {
  name                = azurerm_app_service.app_service.name
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint.private_service_connection[0].private_ip_address]

  # Explicit dependency on the Private Endpoint creation
  depends_on = [azurerm_private_endpoint.private_endpoint]
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "dns-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  # Explicit dependency on the Private DNS Zone creation
  depends_on = [azurerm_private_dns_zone.dns_zone]
}

# Resource to generate a unique name for the app service
resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}
