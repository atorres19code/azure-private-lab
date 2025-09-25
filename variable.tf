variable "resource_group_name" {
  description = "El nombre del grupo de recursos de Azure."
  type        = string
  default     = "private-lab-rg"
}

variable "location" {
  description = "La región de Azure para desplegar los recursos."
  type        = string
  default     = "eastus"
}
