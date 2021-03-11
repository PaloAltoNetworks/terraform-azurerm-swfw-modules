variable "location" {
  description = "Region where to deploy VM-Series and dependencies."
  type        = string
}

variable "name_prefix" {
  description = "Prefix to add to all the object names here"
}

variable "instances" {
  description = <<-EOF
  Map of virtual machine instances to create. Keys are instance identifiers, values
  are the per-vm objects containing the attributes unique to specific virtual machines:

  - `mgmt_public_ip_address_id`: the Public IP identifier to assign to the nic0 interface (the management interface which listens on ssh/https).
  - `nic1_public_ip_address_id`: the Public IP identifier to assign to the first data interface (nic1). Assigning to remaining data interfaces is unsupported.
  - `zone`: the Azure Availability Zone identifier ("1", "2", "3"). If unspecified, the Availability Set is created instead.

  Basic:
  ```
  {
    "fw00" = {
      mgmt_public_ip_address_id = azurerm_public_ip.this.id
    }
    "fw01" = { 
      mgmt_public_ip_address_id = azurerm_public_ip.that.id
    }
  }
  ```

  Full example:
  ```
  {
    "fw00" = {
      mgmt_public_ip_address_id = azurerm_public_ip.m0.id
      nic1_public_ip_address_id = azurerm_public_ip.d0.id
      zone                      = "1"
    }
    "fw01" = { 
      mgmt_public_ip_address_id = azurerm_public_ip.m1.id
      nic1_public_ip_address_id = azurerm_public_ip.d1.id
      zone                      = "2"
    }
  }
  ```
  EOF
}

variable "resource_group_name" {
  description = "The resource group name for VM-Series."
  type        = string
}

variable "subnet_mgmt" {
  description = "Management subnet object."
}

variable "data_nics" {
  description = <<-EOF
  List of the network interface specifications shared between all the VM-Series instances.
  Except the Management network interface (which gets `subnet_mgmt`), all the network interfaces are assigned
  to subnets in the same order as in the list.

  - `subnet`: Subnet object to use.
  - `lb_backend_pool_id`: Identifier of the backend pool of the load balancer to associate.
  - `enable_backend_pool`: If false, ignore `lb_backend_pool_id`. Default it false.

  Example:

  ```
  [
    {
      subnet              = { id = var.vmseries_subnet_id_public }
      lb_backend_pool_id  = module.inbound_lb.backend-pool-id
      enable_backend_pool = true
    },
    {
      subnet              = { id = var.vmseries_subnet_id_private }
      lb_backend_pool_id  = module.outbound_lb.backend-pool-id
      enable_backend_pool = true
    },
  ]
  ```

  EOF
}

variable "bootstrap_storage_account" {
  description = "Existing storage account object for bootstrapping and for holding small-sized boot diagnostics. Usually the object is passed from a bootstrap module's output."
}

variable "bootstrap_share_name" {
  description = "Azure File Share holding the bootstrap data. Should reside on `bootstrap_storage_account`. Bootstrapping is omitted if `bootstrap_share_name` is left at null."
  default     = null
  type        = string
}

variable "username" {
  description = "Initial administrative username to use for VM-Series."
  default     = "panadmin"
  type        = string
}

variable "password" {
  description = "Initial administrative password to use for VM-Series."
  type        = string
}

variable "managed_disk_type" {
  description = "Type of Managed Disk which should be created. Possible values are `Standard_LRS`, `StandardSSD_LRS` or `Premium_LRS`. The `Premium_LRS` works only for selected `vm_size` values, details in Azure docs."
  default     = "StandardSSD_LRS"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size (type) to be created. Consult the *VM-Series Deployment Guide* as only a few selected sizes are supported."
  default     = "Standard_D3_v2"
  type        = string
}

variable "custom_image_id" {
  description = "Absolute ID of your own Custom Image to be used for creating new VM-Series. If set, the `username`, `password`, `vm_series_version`, `vm_series_publisher`, `vm_series_offer`, `vm_series_sku` inputs are all ignored (these are used only for published images, not custom ones). The Custom Image is expected to contain PAN-OS software."
  default     = null
  type        = string
}

variable "enable_plan" {
  description = "Enable usage of the Offer/Plan on Azure Marketplace. Even plan sku \"byol\", which means \"bring your own license\", still requires accepting on the Marketplace (as of 2021). Can be set to `false` when using a custom image."
  default     = true
  type        = bool
}

variable "vm_series_publisher" {
  description = "The Azure Publisher identifier for a image which should be deployed."
  default     = "paloaltonetworks"
}

variable "vm_series_offer" {
  description = "The Azure Offer identifier corresponding to a published image. For `vm_series_version` 9.1.1 or above, use \"vmseries-flex\"; for 9.1.0 or below use \"vmseries1\"."
  default     = "vmseries-flex"
}

variable "vm_series_sku" {
  description = "VM-series SKU - list available with `az vm image list -o table --all --publisher paloaltonetworks`"
  default     = "bundle2"
  type        = string
}

variable "vm_series_version" {
  description = "VM-series PAN-OS version - list available for a default `vm_series_offer` with `az vm image list -o table --publisher paloaltonetworks --offer vmseries-flex --all`"
  default     = "9.0.4"
  type        = string
}

variable "name_avset" {
  default     = null
  description = "Name of the Availability Set to be created. Can be `null`, in which case a default name is auto-generated."
  type        = string
}

variable "tags" {
  description = "A map of tags to be associated with the resources created."
  default     = {}
  type        = map
}

variable "identity_type" {
  description = "See the [provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#identity_type)."
  default     = "SystemAssigned"
  type        = string
}

variable "identity_ids" {
  description = "See the [provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#identity_ids)."
  default     = null
  type        = list(string)
}

variable "metrics_retention_in_days" {
  description = "Specifies the retention period in days. Possible values are 0, 30, 60, 90, 120, 180, 270, 365, 550 or 730. Defaults to 90. A special value 0 disables creation of Application Insights altogether."
  default     = null
  type        = number
}

variable "accelerated_networking" {
  description = "Enable Azure accelerated networking (SR-IOV) for all network interfaces except the primary one (it is the PAN-OS management interface, which [does not support](https://docs.paloaltonetworks.com/pan-os/9-0/pan-os-new-features/virtualization-features/support-for-azure-accelerated-networking-sriov) acceleration)."
  default     = true
  type        = bool
}