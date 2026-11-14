# These three map 1:1 onto the GitHub secrets hyperforge-flows needs.
output "ci_role_arn" {
  description = "Set as AWS_CI_ROLE_ARN secret in hyperforge-flows."
  value       = aws_iam_role.ci.arn
}

output "test_subnet_id" {
  description = "Set as TEST_SUBNET_ID secret in hyperforge-flows."
  value       = aws_subnet.test.id
}

output "test_security_group_id" {
  description = "Set as TEST_SG_ID secret in hyperforge-flows."
  value       = aws_security_group.test_hosts.id
}

output "test_host_instance_profile" {
  description = "Instance profile name for test hosts (wired into the modules)."
  value       = aws_iam_instance_profile.test_host.name
}

output "golden_images_bucket" {
  value = aws_s3_bucket.golden_images.bucket
}

output "tfstate_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}
