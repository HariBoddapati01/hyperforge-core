variable "run_id" {
  description = "Unique id for this test run (e.g. CI run id); used in names and tags."
  type        = string
}

variable "hypervisor_leg" {
  description = "Which matrix leg this host serves: kvm, vme, or ahv."
  type        = string
  validation {
    condition     = contains(["kvm", "vme", "ahv"], var.hypervisor_leg)
    error_message = "hypervisor_leg must be kvm, vme, or ahv (hyperv uses the hyperv-metal module)."
  }
}

variable "instance_type" {
  description = "Nitro instance type with nested-KVM support."
  type        = string
  default     = "c6i.metal" # see README: non-metal Nitro nested KVM caveats
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_name" {
  description = "EC2 key pair for debug SSH; CI normally uses SSM instead."
  type        = string
  default     = null
}

variable "root_volume_gb" {
  description = "Root volume size; must fit the imported lab guest image."
  type        = number
  default     = 200
}

variable "lab_image_s3_uri" {
  description = "s3:// URI of the lab guest qcow2 to import on boot."
  type        = string
}

variable "guest_name" {
  type    = string
  default = "lab-guest"
}

variable "guest_memory_mb" {
  type    = number
  default = 16384
}

variable "guest_vcpus" {
  type    = number
  default = 8
}

variable "guest_extra_disk_gb" {
  description = "Sizes (GB) of empty data disks created and attached to the guest, in order. Nutanix CE needs its hot/cold tiers, e.g. [200, 500]."
  type        = list(number)
  default     = []
}

variable "ttl" {
  description = "Max lifetime before the reaper force-terminates this host (Go duration, e.g. 2h)."
  type        = string
  default     = "2h"
}

variable "tags" {
  type    = map(string)
  default = {}
}
