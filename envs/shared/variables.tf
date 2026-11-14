variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "github_owner" {
  description = "GitHub account whose hyperforge-flows repo may assume the CI role."
  type        = string
  default     = "HariBoddapati01"
}

variable "tfstate_bucket" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string
  default     = "hyperforge-tfstate"
}

variable "golden_images_bucket" {
  description = "Globally unique S3 bucket name for golden images."
  type        = string
  default     = "hyperforge-golden-images"
}
