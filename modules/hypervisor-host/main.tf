// One module for every hypervisor. All per-hypervisor knowledge lives in
// profiles/<hypervisor>.yaml; this module only interprets the profile:
// which host AMI, spot or on-demand, Linux cloud-init or Windows userdata,
// and the guest's shape. Adding a hypervisor = adding a profile file.

locals {
  profile = yamldecode(file("${var.profiles_dir}/${var.hypervisor}.yaml"))

  instance_type  = coalesce(var.instance_type, local.profile.instance_type)
  root_volume_gb = coalesce(var.root_volume_gb, local.profile.root_volume_gb)

  guest = {
    memory_mb     = coalesce(var.guest_memory_mb, local.profile.guest.memory_mb)
    vcpus         = coalesce(var.guest_vcpus, local.profile.guest.vcpus)
    extra_disk_gb = var.guest_extra_disk_gb != null ? var.guest_extra_disk_gb : local.profile.guest.extra_disk_gb
  }

  # A profile may name its own userdata template (e.g. kubevirt applies a
  # VirtualMachine CR instead of running virt-install); otherwise the
  # platform default applies.
  userdata_template = lookup(
    local.profile,
    "userdata_template",
    local.profile.platform == "windows" ? "userdata.ps1.tpl" : "cloud-init.yaml.tpl",
  )

  user_data = templatefile(
    "${path.module}/templates/${local.userdata_template}",
    {
      lab_image_s3_uri = var.lab_image_s3_uri
      guest_name       = var.guest_name
      guest_memory_mb  = local.guest.memory_mb
      guest_vcpus      = local.guest.vcpus
      extra_disk_gb    = local.guest.extra_disk_gb
    }
  )
}

data "aws_ami" "host" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${local.profile.host_ami_prefix}-*"]
  }
}

resource "aws_instance" "host" {
  ami                  = data.aws_ami.host.id
  instance_type        = local.instance_type
  subnet_id            = var.subnet_id
  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile

  vpc_security_group_ids = [var.security_group_id]

  dynamic "instance_market_options" {
    for_each = local.profile.purchase == "spot" ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }

  root_block_device {
    volume_size = local.root_volume_gb
    volume_type = "gp3"
  }

  user_data = local.user_data

  tags = merge(var.tags, {
    Name           = "hyperforge-${var.hypervisor}-${var.run_id}"
    ephemeral-test = "true"
    run-id         = var.run_id
    hypervisor     = var.hypervisor
    ttl-expires-at = timeadd(timestamp(), var.ttl)
  })

  lifecycle {
    ignore_changes = [tags["ttl-expires-at"]]
  }
}
