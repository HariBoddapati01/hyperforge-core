terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    # bucket/region supplied via -backend-config in CI; key is set per run:
    #   terraform init -backend-config="key=runs/${RUN_ID}/${LEG}.tfstate" ...
    # Separate state per run+leg is what makes parallel matrix runs safe.
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = "hyperforge"
      managed-by = "terraform"
    }
  }
}

module "nested_kvm" {
  source = "../../modules/nested-kvm"
  count  = contains(["kvm", "vme"], var.leg) ? 1 : 0

  run_id            = var.run_id
  hypervisor_leg    = var.leg
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id
  lab_image_s3_uri  = var.lab_image_s3_uri
  instance_type     = var.instance_type
  ttl               = var.ttl
}

module "hyperv_metal" {
  source = "../../modules/hyperv-metal"
  count  = var.leg == "hyperv" ? 1 : 0

  run_id            = var.run_id
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id
  lab_image_s3_uri  = var.lab_image_s3_uri
  instance_type     = var.instance_type != null ? var.instance_type : "m6i.metal"
  ttl               = var.ttl
}

output "host_instance_id" {
  value = var.leg == "hyperv" ? module.hyperv_metal[0].instance_id : module.nested_kvm[0].instance_id
}

output "host_private_ip" {
  value = var.leg == "hyperv" ? module.hyperv_metal[0].private_ip : module.nested_kvm[0].private_ip
}
