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
resource "azurerm_app_service_plan" "asp" {
  name                = "asp-private-lab"
  location            = "mexicocentral"
  resource_group_name = "private-lab-rg"
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Free"
    size = "F1"
  }
}

resource "azurerm_app_service" "app_service" {
  name                = "private-webapp-${random_string.random.result}"
  location            = "mexicocentral"
  resource_group_name = "private-lab-rg"
  app_service_plan_id = azurerm_app_service_plan.asp.id
  site_config {
    linux_fx_version = "NODE|18-lts"
  }
  https_only = true
}

resource "azurerm_private_endpoint" "private_endpoint" {
  name                = "pep-app-service"
  location            = "mexicocentral"
  resource_group_name = "private-lab-rg"
  subnet_id           = "/subscriptions/6e33a595-50a1-4389-9b98-639a66718d04/resourceGroups/private-lab-rg/providers/Microsoft.Network/virtualNetworks/vnet-private-lab/subnets/subnet-app-service"

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
resource "azurerm_private_dns_a_record" "dns_a_record" {
  name                = azurerm_app_service.app_service.name
  zone_name           = "privatelink.azurewebsites.net"
  resource_group_name = "private-lab-rg"
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint.private_service_connection[0].private_ip_address]

  # Explicit dependency on the Private Endpoint creation
  depends_on = [azurerm_private_endpoint.private_endpoint]
}

# Resource to generate a unique name for the app service
resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}
