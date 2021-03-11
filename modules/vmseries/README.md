# Palo Alto Networks VM-Series Module for Azure

A Terraform module for deploying a VM-Series firewall in Azure cloud.
The module is not intended for use with Scale Sets.

## Usage

```hcl
module "vmseries" {
  source  = "github.com/PaloAltoNetworks/terraform-azurerm-vmseries-modules//modules/vmseries"

  location                      = "Australia Central"
  name_prefix                   = "panostf"
  password                      = "your-password"
  bootstrap_storage_account     = module.vm-bootstrap.bootstrap_storage_account
  bootstrap_share_name          = "sharename"
  subnet_mgmt                   = module.networks.subnet_mgmt
  data_nics = [
    {
      subnet              = module.networks.subnet_public
      enable_backend_pool = false
    },
    {
      subnet              = module.networks.subnet_private
      enable_backend_pool = false
    },
  ]
  instances = {
    "my-firewall" = {}
  }
}
```

___NOTE:___ The module only supports Azure regions that have more than one fault domain - as of 2021, the only two regions impacted are `SouthCentralUSSTG` and `CentralUSEUAP`. The reason is that the module uses Availability Sets with Managed Disks.

[Instruction to re-check regions](https://docs.microsoft.com/en-us/azure/virtual-machines/manage-availability#use-managed-disks-for-vms-in-an-availability-set).

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >=0.12.29, <0.14 |
| azurerm | >=2.26.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >=2.26.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| accelerated\_networking | Enable Azure accelerated networking (SR-IOV) for all network interfaces except the primary one (it is the PAN-OS management interface, which [does not support](https://docs.paloaltonetworks.com/pan-os/9-0/pan-os-new-features/virtualization-features/support-for-azure-accelerated-networking-sriov) acceleration). | `bool` | `true` | no |
| bootstrap\_share\_name | Azure File Share holding the bootstrap data. Should reside on `bootstrap_storage_account`. Bootstrapping is omitted if `bootstrap_share_name` is left at null. | `string` | `null` | no |
| bootstrap\_storage\_account | Existing storage account object for bootstrapping and for holding small-sized boot diagnostics. Usually the object is passed from a bootstrap module's output. | `any` | n/a | yes |
| custom\_image\_id | Absolute ID of your own Custom Image to be used for creating new VM-Series. If set, the `username`, `password`, `vm_series_version`, `vm_series_publisher`, `vm_series_offer`, `vm_series_sku` inputs are all ignored (these are used only for published images, not custom ones). The Custom Image is expected to contain PAN-OS software. | `string` | `null` | no |
| data\_nics | List of the network interface specifications shared between all the VM-Series instances.<br>Except the Management network interface (which gets `subnet_mgmt`), all the network interfaces are assigned<br>to subnets in the same order as in the list.<br><br>- `subnet`: Subnet object to use.<br>- `lb_backend_pool_id`: Identifier of the backend pool of the load balancer to associate.<br>- `enable_backend_pool`: If false, ignore `lb_backend_pool_id`. Default it false.<br><br>Example:<pre>[<br>  {<br>    subnet              = { id = var.vmseries_subnet_id_public }<br>    lb_backend_pool_id  = module.inbound_lb.backend-pool-id<br>    enable_backend_pool = true<br>  },<br>  {<br>    subnet              = { id = var.vmseries_subnet_id_private }<br>    lb_backend_pool_id  = module.outbound_lb.backend-pool-id<br>    enable_backend_pool = true<br>  },<br>]</pre> | `any` | n/a | yes |
| enable\_plan | Enable usage of the Offer/Plan on Azure Marketplace. Even plan sku "byol", which means "bring your own license", still requires accepting on the Marketplace (as of 2021). Can be set to `false` when using a custom image. | `bool` | `true` | no |
| identity\_ids | See the [provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#identity_ids). | `list(string)` | `null` | no |
| identity\_type | See the [provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine#identity_type). | `string` | `"SystemAssigned"` | no |
| instances | Map of virtual machine instances to create. Keys are instance identifiers, values<br>are the per-vm objects containing the attributes unique to specific virtual machines:<br><br>- `mgmt_public_ip_address_id`: the Public IP identifier to assign to the nic0 interface (the management interface which listens on ssh/https).<br>- `nic1_public_ip_address_id`: the Public IP identifier to assign to the first data interface (nic1). Assigning to remaining data interfaces is unsupported.<br>- `zone`: the Azure Availability Zone identifier ("1", "2", "3"). If unspecified, the Availability Set is created instead.<br><br>Basic:<pre>{<br>  "fw00" = {<br>    mgmt_public_ip_address_id = azurerm_public_ip.this.id<br>  }<br>  "fw01" = { <br>    mgmt_public_ip_address_id = azurerm_public_ip.that.id<br>  }<br>}</pre>Full example:<pre>{<br>  "fw00" = {<br>    mgmt_public_ip_address_id = azurerm_public_ip.m0.id<br>    nic1_public_ip_address_id = azurerm_public_ip.d0.id<br>    zone                      = "1"<br>  }<br>  "fw01" = { <br>    mgmt_public_ip_address_id = azurerm_public_ip.m1.id<br>    nic1_public_ip_address_id = azurerm_public_ip.d1.id<br>    zone                      = "2"<br>  }<br>}</pre> | `any` | n/a | yes |
| location | Region where to deploy VM-Series and dependencies. | `string` | n/a | yes |
| managed\_disk\_type | Type of Managed Disk which should be created. Possible values are `Standard_LRS`, `StandardSSD_LRS` or `Premium_LRS`. The `Premium_LRS` works only for selected `vm_size` values, details in Azure docs. | `string` | `"StandardSSD_LRS"` | no |
| metrics\_retention\_in\_days | Specifies the retention period in days. Possible values are 0, 30, 60, 90, 120, 180, 270, 365, 550 or 730. Defaults to 90. A special value 0 disables creation of Application Insights altogether. | `number` | `null` | no |
| name\_avset | Name of the Availability Set to be created. Can be `null`, in which case a default name is auto-generated. | `string` | `null` | no |
| name\_prefix | Prefix to add to all the object names here | `any` | n/a | yes |
| password | Initial administrative password to use for VM-Series. | `string` | n/a | yes |
| resource\_group\_name | The resource group name for VM-Series. | `string` | n/a | yes |
| subnet\_mgmt | Management subnet object. | `any` | n/a | yes |
| tags | A map of tags to be associated with the resources created. | `map` | `{}` | no |
| username | Initial administrative username to use for VM-Series. | `string` | `"panadmin"` | no |
| vm\_series\_offer | The Azure Offer identifier corresponding to a published image. For `vm_series_version` 9.1.1 or above, use "vmseries-flex"; for 9.1.0 or below use "vmseries1". | `string` | `"vmseries-flex"` | no |
| vm\_series\_publisher | The Azure Publisher identifier for a image which should be deployed. | `string` | `"paloaltonetworks"` | no |
| vm\_series\_sku | VM-series SKU - list available with `az vm image list -o table --all --publisher paloaltonetworks` | `string` | `"bundle2"` | no |
| vm\_series\_version | VM-series PAN-OS version - list available for a default `vm_series_offer` with `az vm image list -o table --publisher paloaltonetworks --offer vmseries-flex --all` | `string` | `"9.0.4"` | no |
| vm\_size | Azure VM size (type) to be created. Consult the *VM-Series Deployment Guide* as only a few selected sizes are supported. | `string` | `"Standard_D3_v2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| ip\_addresses | VM-Series management IP addresses. |
| metrics\_instrumentation\_key | The Instrumentation Key of the created instance of Azure Application Insights. The instance is unused by default, but is ready to receive custom PAN-OS metrics from the firewalls. To use it, paste this Instrumentation Key into PAN-OS -> Device -> VM-Series -> Azure. |
| principal\_id | A map of Azure Service Principals for each of the created VM-Series. Map's key is the same as virtual machine key, the value is an oid of a Service Principal. Usable only if `identity_type` contains SystemAssigned. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Custom Metrics

**(Optional)** Firewalls can publish custom metrics (for example `panSessionUtilization`) to Azure Application Insights.
This however requires a manual initialization: copy the output `metrics_instrumentation_key` and paste it into your
PAN-OS webUI -> Device -> VM-Series -> Azure. The module automatically completes the Step 1 of the
[official procedure](https://docs.paloaltonetworks.com/vm-series/10-0/vm-series-deployment/set-up-the-vm-series-firewall-on-azure/enable-azure-application-insights-on-the-vm-series-firewall.html).

The metrics gathered within a single Azure Application Insights instance provided by the module, cannot be split to obtain
back a result for solely a single firewall. Thus for example if three firewalls use the same Instrumentation Key and report
their respective session utilizations as 90%, 20%, 10%, it is possible to see in Azure the average of 40%, the sum of 120%, the max of 90%, but it is *not possible* to know which of the firewalls reported the 90% utilization.