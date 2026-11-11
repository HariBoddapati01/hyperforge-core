output "instance_id" {
  value = aws_spot_instance_request.kvm_host.spot_instance_id
}

output "private_ip" {
  value = aws_spot_instance_request.kvm_host.private_ip
}

output "public_ip" {
  value = aws_spot_instance_request.kvm_host.public_ip
}
