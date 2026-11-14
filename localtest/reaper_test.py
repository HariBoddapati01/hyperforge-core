"""Exercise the TTL reaper's actual handler against the local mock:
an expired ephemeral instance must die, a fresh one and an untagged one
must survive."""

import importlib.util
import os
from datetime import datetime, timedelta, timezone

import boto3

REGION = os.environ.get("AWS_REGION", "us-east-2")
REAPER = os.path.join(
    os.path.dirname(__file__), "..", "modules", "ttl-reaper", "lambda", "reaper.py"
)


def run_instance(ec2, ami, tags):
    out = ec2.run_instances(ImageId=ami, MinCount=1, MaxCount=1, InstanceType="t3.micro")
    iid = out["Instances"][0]["InstanceId"]
    if tags:
        ec2.create_tags(Resources=[iid], Tags=[{"Key": k, "Value": v} for k, v in tags.items()])
    return iid


def state(ec2, iid):
    r = ec2.describe_instances(InstanceIds=[iid])
    return r["Reservations"][0]["Instances"][0]["State"]["Name"]


def main():
    ec2 = boto3.client("ec2", region_name=REGION)
    ami = ec2.describe_images(Owners=["self"])["Images"][0]["ImageId"]

    now = datetime.now(timezone.utc)
    expired = run_instance(ec2, ami, {
        "ephemeral-test": "true",
        "run-id": "reaper-test-expired",
        "ttl-expires-at": (now - timedelta(hours=1)).isoformat(),
    })
    fresh = run_instance(ec2, ami, {
        "ephemeral-test": "true",
        "run-id": "reaper-test-fresh",
        "ttl-expires-at": (now + timedelta(hours=2)).isoformat(),
    })
    untagged = run_instance(ec2, ami, {})

    spec = importlib.util.spec_from_file_location("reaper", REAPER)
    reaper = importlib.util.module_from_spec(spec)
    os.environ["DRY_RUN"] = "false"
    spec.loader.exec_module(reaper)
    result = reaper.handler({}, None)

    assert expired in result["reaped"], f"expired instance not reaped: {result}"
    assert fresh not in result["reaped"], "fresh instance wrongly reaped"
    assert untagged not in result["reaped"], "untagged instance wrongly reaped"
    assert state(ec2, expired) == "terminated", "expired instance not actually terminated"
    assert state(ec2, fresh) == "running", "fresh instance should still run"
    assert state(ec2, untagged) == "running", "untagged instance should still run"

    print(f"  OK: reaper terminated only the expired instance ({expired})")


if __name__ == "__main__":
    main()
