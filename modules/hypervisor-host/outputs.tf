output "instance_id" {
  value = aws_instance.host.id
}

output "private_ip" {
  value = aws_instance.host.private_ip
}

output "public_ip" {
  value = aws_instance.host.public_ip
}

output "hypervisor" {
  value = var.hypervisor
}

output "platform" {
  value = local.profile.platform
}
