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

module "host" {
  source = "../../modules/hypervisor-host"

  hypervisor   = var.leg
  profiles_dir = "${path.root}/../../profiles"

  run_id            = var.run_id
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id
  lab_image_s3_uri  = var.lab_image_s3_uri
  instance_type     = var.instance_type
  ttl               = var.ttl
}

output "host_instance_id" {
  value = module.host.instance_id
}

output "host_private_ip" {
  value = module.host.private_ip
}

output "host_platform" {
  value = module.host.platform
}
