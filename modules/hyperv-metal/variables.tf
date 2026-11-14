variable "run_id" {
  type = string
}

variable "instance_type" {
  description = "Bare-metal type; m6i.metal is the price/perf default, z1d.metal for high clock."
  type        = string
  default     = "m6i.metal"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "root_volume_gb" {
  type    = number
  default = 300
}

variable "lab_image_s3_uri" {
  description = "s3:// URI of the exported lab Hyper-V guest (VHDX)."
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

variable "ttl" {
  description = "Max lifetime before the reaper force-terminates this host."
  type        = string
  default     = "3h"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "iam_instance_profile" {
  description = "Instance profile granting SSM access and golden-image reads (from envs/shared)."
  type        = string
  default     = "hyperforge-test-host"
}
