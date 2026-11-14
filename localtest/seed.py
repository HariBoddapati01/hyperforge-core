"""Seed the local AWS mock with what envs/test expects to find:
golden-image bucket + objects, host AMIs matching the profile name filters,
and a VPC/subnet/SG. Prints shell exports for run.sh to eval."""

import os

import boto3

REGION = os.environ.get("AWS_REGION", "us-east-2")


def main():
    ec2 = boto3.client("ec2", region_name=REGION)
    s3 = boto3.client("s3", region_name=REGION)
    iam = boto3.client("iam", region_name=REGION)

    iam.create_role(
        RoleName="hyperforge-test-host",
        AssumeRolePolicyDocument='{"Version":"2012-10-17","Statement":[{"Effect":"Allow",'
        '"Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}',
    )
    iam.create_instance_profile(InstanceProfileName="hyperforge-test-host")
    iam.add_role_to_instance_profile(
        InstanceProfileName="hyperforge-test-host", RoleName="hyperforge-test-host"
    )

    for bucket in ("hyperforge-tfstate", "hyperforge-golden-images"):
        s3.create_bucket(
            Bucket=bucket,
            CreateBucketConfiguration={"LocationConstraint": REGION},
        )
    for leg, ext in (("kvm", "qcow2"), ("vme", "qcow2"), ("ahv", "qcow2"), ("hyperv", "vhdx")):
        key = f"golden/{leg}/deadbeef.{ext}"
        s3.put_object(Bucket="hyperforge-golden-images", Key=key, Body=b"fake-image")

    for prefix in ("hyperforge-kvm-host", "hyperforge-hyperv-host", "hyperforge-kubevirt-host"):
        ec2.register_image(
            Name=f"{prefix}-1700000000",
            Architecture="x86_64",
            RootDeviceName="/dev/sda1",
            VirtualizationType="hvm",
        )

    vpc = ec2.create_vpc(CidrBlock="10.42.0.0/16")["Vpc"]["VpcId"]
    subnet = ec2.create_subnet(VpcId=vpc, CidrBlock="10.42.1.0/24")["Subnet"]["SubnetId"]
    sg = ec2.create_security_group(
        GroupName="hyperforge-test-hosts", Description="egress only", VpcId=vpc
    )["GroupId"]

    print(f"export SEED_SUBNET_ID={subnet}")
    print(f"export SEED_SG_ID={sg}")


if __name__ == "__main__":
    main()
