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
# Configuración del Laboratorio de Azure
# Despliega un App Service accesible solo desde una red privada
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
  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "app_service" {
  name                = "private-webapp-${random_string.random.result}" # Nombre único
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
  site_config {
    linux_fx_version = "NODE|18-lts" # Puedes cambiar esto por la pila que necesites (ej. "DOTNET|6.0", "PYTHON|3.9")
  }
  https_only = true
}

resource "azurerm_private_endpoint" "private_endpoint" {
  name                = "pep-app-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id

  # Conexión al servicio de App Service
  private_service_connection {
    name                           = "app-service-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_app_service.app_service.id
    subresource_names              = ["sites"]
  }
}

# La zona DNS privada es necesaria para que el VNet pueda resolver el FQDN del App Service a su IP privada
resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_a_record" "dns_a_record" {
  name                = azurerm_app_service.app_service.name
  zone_name           = azurerm_private_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint.private_service_connection[0].private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "dns-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Recurso para generar un nombre único para la app service
resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}
