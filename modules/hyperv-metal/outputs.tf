output "instance_id" {
  value = aws_instance.hyperv_host.id
}

output "private_ip" {
  value = aws_instance.hyperv_host.private_ip
}

output "public_ip" {
  value = aws_instance.hyperv_host.public_ip
}
