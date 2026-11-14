variable "hypervisor" {
  description = "Which hypervisor to build — must match a profiles/<name>.yaml file."
  type        = string
}

variable "profiles_dir" {
  description = "Directory holding the hypervisor profile YAMLs."
  type        = string
}

variable "run_id" {
  description = "Unique id for this test run; used in names and tags."
  type        = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "lab_image_s3_uri" {
  description = "s3:// URI of the golden guest image to import on boot."
  type        = string
}

variable "iam_instance_profile" {
  description = "Instance profile granting SSM access and golden-image reads (from envs/shared)."
  type        = string
  default     = "hyperforge-test-host"
}

variable "key_name" {
  description = "EC2 key pair for debug access; CI normally uses SSM instead."
  type        = string
  default     = null
}

variable "ttl" {
  description = "Max lifetime before the reaper force-terminates this host (Go duration, e.g. 2h)."
  type        = string
  default     = "2h"
}

# Overrides — null means "use the profile's value".

variable "instance_type" {
  type    = string
  default = null
}

variable "root_volume_gb" {
  type    = number
  default = null
}

variable "guest_name" {
  type    = string
  default = "lab-guest"
}

variable "guest_memory_mb" {
  type    = number
  default = null
}

variable "guest_vcpus" {
  type    = number
  default = null
}

variable "guest_extra_disk_gb" {
  type    = list(number)
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
