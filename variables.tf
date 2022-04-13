
# ##################################################
# # Azure and IBM Authentication Variables
# ##################################################

variable "TF_VERSION" {
  description = "terraform version"
  type        = string
  default     = "0.13"
}


variable "is_az_resource_group_exist" {
  default     = false
  description = "If false, resource group (az_resource_group) will be created. If true, existing resource group (az_resource_group) will be read"
  type        = bool
}

variable "az_resource_group" {
  description = "Name of the resource Group"
  type        = string
  default     = "satellite-azure"
}
variable "az_region" {
  description = "Azure Region"
  type        = string
  default     = "eastus"
}
variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key"
  type        = string
}
variable "ibm_resource_group" {
  description = "Resource group name of the IBM Cloud account."
  type        = string
  default     = "default"
}

# ##################################################
# # Azure Resources Variables
# ##################################################

variable "az_vpc" {
  description = "Virtual Network Name VPC name"
  type        = string
  default     = "satellite-azure-vpc"
}
variable "az_resource_prefix" {
  description = "Name to be used on all azure resources as prefix"
  type        = string
  default     = "satellite-azure"
}
variable "az_worker_resource_prefix" {
  description = "Name to be used on all azure worker host resources as prefix"
  type        = string
  default     = "satellite-azure-worker"
}
variable "ssh_public_key" {
  description = "SSH Public Key. Get your ssh key by running `ssh-key-gen` command"
  type        = string
  default     = null
}
variable "instance_type" {
  description = "The type of azure instance to start"
  type        = string
  default     = "Standard_D4s_v3"
}
variable "worker_instance_type" {
  description = "The type of azure instance to start"
  type        = string
  default     = "Standard_D4s_v3"
}
variable "satellite_host_count" {
  description = "The total number of Azure host to create for control plane. "
  type        = number
  default     = 3
  validation {
    condition     = (var.satellite_host_count % 3) == 0 && var.satellite_host_count > 0
    error_message = "Sorry, host_count value should always be in multiples of 3, such as 6, 9, or 12 hosts."
  }
}
variable "addl_host_count" {
  description = "The total number of additional azure vm's"
  type        = number
  default     = 0
}

# ##################################################
# # IBMCLOUD Satellite Location Variables
# ##################################################

variable "location" {
  description = "Location Name"
  default     = "satellite-azure"

  validation {
    condition     = var.location != "" && length(var.location) <= 32
    error_message = "Sorry, please provide value for location_name variable or check the length of name it should be less than 32 chars."
  }
}
variable "is_location_exist" {
  description = "Determines if the location has to be created or not"
  type        = bool
  default     = false
}

variable "managed_from" {
  description = "The IBM Cloud region to manage your Satellite location from. Choose a region close to your on-prem data center for better performance."
  type        = string
  default     = "wdc"
}

variable "location_zones" {
  description = "Allocate your hosts across these three zones"
  type        = list(string)
  default     = ["us-east-1", "us-east-2", "us-east-3"]
}

variable "location_bucket" {
  description = "COS bucket name"
  default     = ""
}

variable "host_labels" {
  description = "Labels to add to attach host script"
  type        = list(string)
  default     = ["env:prod"]

  validation {
    condition     = can([for s in var.host_labels : regex("^[a-zA-Z0-9:]+$", s)])
    error_message = "Label must be of the form `key:value`."
  }
}








##################################################
# IBMCLOUD ROKS Cluster Variables
##################################################

variable "create_cluster" {
  description = "Create Cluster: Disable this, not to provision cluster"
  type        = bool
  default     = true
}

variable "cluster" {
  description = "Satellite Location Name"
  type        = string
  default     = "satellite-ibm-cluster"

  validation {
    error_message = "Cluster name must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.cluster))
  }
}

variable "kube_version" {
  description = "Satellite Kube Version"
  default     = "4.7_openshift"
}

variable "worker_count" {
  description = "Worker Count for default pool"
  type        = number
  default     = 1
}

variable "wait_for_worker_update" {
  description = "Wait for worker update"
  type        = bool
  default     = true
}

variable "default_worker_pool_labels" {
  description = "Label to add default worker pool"
  type        = map(any)
  default     = null
}

variable "tags" {
  description = "List of tags associated with cluster."
  type        = list(string)
  default     = null
}

variable "create_timeout" {
  type        = string
  description = "Timeout duration for create."
  default     = null
}

variable "update_timeout" {
  type        = string
  description = "Timeout duration for update."
  default     = null
}

variable "delete_timeout" {
  type        = string
  description = "Timeout duration for delete."
  default     = null
}

##################################################
# IBMCLOUD ROKS Cluster Worker Pool Variables
##################################################
variable "create_cluster_worker_pool" {
  description = "Create Cluster worker pool"
  type        = bool
  default     = false
}

variable "worker_pool_name" {
  description = "Satellite Location Name"
  type        = string
  default     = "satellite-worker-pool"

  validation {
    error_message = "Cluster name must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.worker_pool_name))
  }

}

variable "worker_pool_host_labels" {
  description = "Labels to add to attach host script"
  type        = list(string)
  default     = ["env:prod"]

  validation {
    condition     = can([for s in var.worker_pool_host_labels : regex("^[a-zA-Z0-9:]+$", s)])
    error_message = "Label must be of the form `key:value`."
  }
}