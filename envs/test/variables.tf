variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "run_id" {
  description = "CI run id; makes every resource name unique per run."
  type        = string
}

variable "leg" {
  description = "Matrix leg — any hypervisor with a profiles/<name>.yaml file."
  type        = string
  validation {
    condition     = contains([for f in fileset("${path.root}/../../profiles", "*.yaml") : trimsuffix(f, ".yaml")], var.leg)
    error_message = "leg must match a profile in profiles/ (one of the *.yaml basenames)."
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
