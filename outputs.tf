### **3. `outputs.tf`**

Este archivo te mostrará información clave al finalizar el despliegue, como la URL de tu aplicación y la IP privada.

```terraform:Resultados:outputs.tf
output "app_service_url" {
  description = "URL para acceder a la aplicación web (solo accesible desde el VNet)."
  value       = azurerm_app_service.app_service.default_site_hostname
}

output "private_ip" {
  description = "La IP privada del Private Endpoint."
  value       = azurerm_private_endpoint.private_endpoint.private_service_connection[0].private_ip_address
}

```eof
---

