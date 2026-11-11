variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "run_id" {
  description = "CI run id; makes every resource name unique per run."
  type        = string
}

variable "leg" {
  description = "Matrix leg: kvm, vme, or hyperv."
  type        = string
  validation {
    condition     = contains(["kvm", "vme", "hyperv"], var.leg)
    error_message = "leg must be one of: kvm, vme, hyperv."
  }
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "lab_image_s3_uri" {
  type = string
}

variable "instance_type" {
  description = "Override the leg's default instance type."
  type        = string
  default     = null
}

variable "ttl" {
  type    = string
  default = "2h"
}
