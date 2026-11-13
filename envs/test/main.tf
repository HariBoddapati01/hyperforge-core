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

# Per-leg guest sizing. ahv = Nutanix CE single node: the CVM alone wants
# ~20GB RAM, and CE needs hot/cold data tiers beyond the boot disk.
locals {
  guest_defaults = {
    kvm = { memory_mb = 16384, vcpus = 8, extra_disk_gb = [] }
    vme = { memory_mb = 24576, vcpus = 8, extra_disk_gb = [] }
    ahv = { memory_mb = 49152, vcpus = 12, extra_disk_gb = [200, 500] }
  }
}

module "nested_kvm" {
  source = "../../modules/nested-kvm"
  count  = contains(["kvm", "vme", "ahv"], var.leg) ? 1 : 0

  run_id              = var.run_id
  hypervisor_leg      = var.leg
  subnet_id           = var.subnet_id
  security_group_id   = var.security_group_id
  lab_image_s3_uri    = var.lab_image_s3_uri
  # ahv benefits from local NVMe for CE's storage tiers
  instance_type       = coalesce(var.instance_type, var.leg == "ahv" ? "i4i.metal" : "c6i.metal")
  ttl                 = var.ttl
  guest_memory_mb     = lookup(local.guest_defaults, var.leg, local.guest_defaults["kvm"]).memory_mb
  guest_vcpus         = lookup(local.guest_defaults, var.leg, local.guest_defaults["kvm"]).vcpus
  guest_extra_disk_gb = lookup(local.guest_defaults, var.leg, local.guest_defaults["kvm"]).extra_disk_gb
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
