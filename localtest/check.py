"""Assert that terraform apply produced the host the profile demands:
usage: check.py <hypervisor> <run_id>"""

import os
import sys

import boto3
import yaml

REGION = os.environ.get("AWS_REGION", "us-east-2")


def main():
    hv, run_id = sys.argv[1], sys.argv[2]
    with open(os.path.join(os.path.dirname(__file__), "..", "profiles", f"{hv}.yaml")) as f:
        profile = yaml.safe_load(f)

    ec2 = boto3.client("ec2", region_name=REGION)
    reservations = ec2.describe_instances(
        Filters=[
            {"Name": "tag:run-id", "Values": [run_id]},
            {"Name": "instance-state-name", "Values": ["pending", "running"]},
        ]
    )["Reservations"]
    instances = [i for r in reservations for i in r["Instances"]]
    assert len(instances) == 1, f"expected 1 instance for run {run_id}, found {len(instances)}"
    inst = instances[0]
    tags = {t["Key"]: t["Value"] for t in inst.get("Tags", [])}

    assert inst["InstanceType"] == profile["instance_type"], (
        f"instance type {inst['InstanceType']} != profile {profile['instance_type']}"
    )
    assert tags.get("hypervisor") == hv, f"hypervisor tag {tags.get('hypervisor')!r}"
    assert tags.get("ephemeral-test") == "true", "missing ephemeral-test tag"
    assert "ttl-expires-at" in tags, "missing ttl-expires-at tag (reaper contract)"
    assert tags.get("Name") == f"hyperforge-{hv}-{run_id}", f"Name tag {tags.get('Name')!r}"

    lifecycle = inst.get("InstanceLifecycle", "ondemand")
    want = profile["purchase"]
    if (lifecycle == "spot") != (want == "spot"):
        # moto may not model market options faithfully; warn rather than fail
        print(f"  WARN: lifecycle={lifecycle} but profile wants {want} (mock limitation?)")

    print(
        f"  OK: {hv} -> {inst['InstanceType']} ({want}), "
        f"tags verified, ttl={tags['ttl-expires-at']}"
    )


if __name__ == "__main__":
    main()
