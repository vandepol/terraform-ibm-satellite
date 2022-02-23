provider "azurerm" {
  features {}
   subscription_id = var.ARM_SUBSCRIPTION_ID
   client_id       = var.ARM_CLIENT_ID
   tenant_id       = var.ARM_TENANT_ID
   client_secret   = var.ARM_CLIENT_SECRET
}
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
}