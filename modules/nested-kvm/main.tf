data "aws_ami" "kvm_host" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["hv-testbed-kvm-host-*"]
  }
}

resource "aws_spot_instance_request" "kvm_host" {
  ami                            = data.aws_ami.kvm_host.id
  instance_type                  = var.instance_type
  spot_type                      = "one-time"
  wait_for_fulfillment           = true
  instance_interruption_behavior = "terminate"

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    lab_image_s3_uri = var.lab_image_s3_uri
    guest_name       = var.guest_name
    guest_memory_mb  = var.guest_memory_mb
    guest_vcpus      = var.guest_vcpus
  })

  tags = merge(var.tags, {
    Name            = "hv-testbed-kvm-${var.run_id}"
    ephemeral-test  = "true"
    run-id          = var.run_id
    ttl-expires-at  = timeadd(timestamp(), var.ttl)
    hypervisor-leg  = var.hypervisor_leg
  })

  lifecycle {
    ignore_changes = [tags["ttl-expires-at"]]
  }
}

# Tags on the spot request don't propagate to the instance; tag it explicitly
# so the TTL reaper can find it.
resource "aws_ec2_tag" "instance_tags" {
  for_each = merge(var.tags, {
    Name           = "hv-testbed-kvm-${var.run_id}"
    ephemeral-test = "true"
    run-id         = var.run_id
    hypervisor-leg = var.hypervisor_leg
  })

  resource_id = aws_spot_instance_request.kvm_host.spot_instance_id
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "ttl" {
  resource_id = aws_spot_instance_request.kvm_host.spot_instance_id
  key         = "ttl-expires-at"
  value       = timeadd(timestamp(), var.ttl)

  lifecycle {
    ignore_changes = [value]
  }
}
