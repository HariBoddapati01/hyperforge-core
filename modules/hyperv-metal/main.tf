data "aws_ami" "hyperv_host" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["hv-testbed-hyperv-host-*"]
  }
}

# Bare metal: Hyper-V needs real VT-x/SLAT, which nested virt on Nitro VMs
# does not expose reliably. No Spot here — metal Spot capacity is scarce and
# an interruption mid-run wastes the long (~10 min) provision time.
resource "aws_instance" "hyperv_host" {
  ami           = data.aws_ami.hyperv_host.id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  get_password_data      = false # CI uses SSM, not RDP

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/userdata.ps1.tpl", {
    lab_image_s3_uri = var.lab_image_s3_uri
    guest_name       = var.guest_name
    guest_memory_mb  = var.guest_memory_mb
    guest_vcpus      = var.guest_vcpus
  })

  tags = merge(var.tags, {
    Name           = "hv-testbed-hyperv-${var.run_id}"
    ephemeral-test = "true"
    run-id         = var.run_id
    ttl-expires-at = timeadd(timestamp(), var.ttl)
    hypervisor-leg = "hyperv"
  })

  lifecycle {
    ignore_changes = [tags["ttl-expires-at"]]
  }
}
