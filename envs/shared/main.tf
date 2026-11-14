// One-time account bootstrap for HyperForge. Applied once by a human with
// admin credentials (not by CI); everything per-run lives in envs/test.
//
//   terraform init && terraform apply
//
// State for THIS root is local by default (the state bucket doesn't exist
// until this applies). After the first apply you can migrate it into the
// bucket with the commented backend below + `terraform init -migrate-state`.

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

  # After first apply, uncomment and run `terraform init -migrate-state`:
  # backend "s3" {
  #   bucket = "hyperforge-tfstate"
  #   key    = "shared/bootstrap.tfstate"
  #   region = "us-east-2"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = "hyperforge"
      managed-by = "terraform"
      stack      = "shared"
    }
  }
}

# ---------------------------------------------------------------- S3 buckets

resource "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket
}

resource "aws_s3_bucket" "golden_images" {
  bucket = var.golden_images_bucket
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "golden_images" {
  bucket                  = aws_s3_bucket.golden_images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old per-run state files have no value after a few months.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-run-states"
    status = "Enabled"
    filter {
      prefix = "runs/"
    }
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ------------------------------------------------------------------- Network
# Public subnet + public IPs + egress-only SG: hosts reach S3/SSM without a
# NAT gateway (which would cost ~$32/mo idle), and nothing can dial in.

resource "aws_vpc" "test" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "hyperforge-test" }
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = { Name = "hyperforge-test" }
}

resource "aws_subnet" "test" {
  vpc_id                  = aws_vpc.test.id
  cidr_block              = "10.42.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "hyperforge-test" }
}

resource "aws_route_table" "test" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = { Name = "hyperforge-test" }
}

resource "aws_route_table_association" "test" {
  subnet_id      = aws_subnet.test.id
  route_table_id = aws_route_table.test.id
}

resource "aws_security_group" "test_hosts" {
  name        = "hyperforge-test-hosts"
  description = "HyperForge ephemeral test hosts: egress only, access via SSM"
  vpc_id      = aws_vpc.test.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------- Test host instance profile

resource "aws_iam_role" "test_host" {
  name = "hyperforge-test-host"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "test_host_ssm" {
  role       = aws_iam_role.test_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "test_host_images" {
  name = "golden-images-read"
  role = aws_iam_role.test_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.golden_images.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.golden_images.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "test_host" {
  name = "hyperforge-test-host"
  role = aws_iam_role.test_host.name
}

# ------------------------------------------------------- GitHub Actions OIDC

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "ci" {
  name = "hyperforge-ci"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/hyperforge-flows:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ci" {
  name = "hyperforge-ci"
  role = aws_iam_role.ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Ec2Lifecycle"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:RequestSpotInstances",
          "ec2:CancelSpotInstanceRequests",
          "ec2:GetConsoleOutput"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassHostRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.test_host.arn
      },
      {
        Sid    = "State"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
      },
      {
        Sid    = "Images"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.golden_images.arn,
          "${aws_s3_bucket.golden_images.arn}/*"
        ]
      },
      {
        Sid    = "Ssm"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------ Reaper

module "ttl_reaper" {
  source = "../../modules/ttl-reaper"

  # Flip to false after reviewing the reaper's CloudWatch logs.
  dry_run = true
}
