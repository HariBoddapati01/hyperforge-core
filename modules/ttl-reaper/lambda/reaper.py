"""Force-terminate ephemeral test instances that outlived their TTL.

Safety net for CI teardown failures: anything tagged ephemeral-test=true whose
ttl-expires-at (RFC3339) is in the past gets terminated, regardless of what
the pipeline thinks. Runs on an EventBridge schedule (default: every 15 min).
"""

import os
from datetime import datetime, timezone

import boto3

ec2 = boto3.client("ec2")


def handler(event, context):
    now = datetime.now(timezone.utc)
    reaped = []

    paginator = ec2.get_paginator("describe_instances")
    pages = paginator.paginate(
        Filters=[
            {"Name": "tag:ephemeral-test", "Values": ["true"]},
            {"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]},
        ]
    )
    for page in pages:
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
                expires_raw = tags.get("ttl-expires-at")
                if not expires_raw:
                    continue
                try:
                    expires = datetime.fromisoformat(expires_raw.replace("Z", "+00:00"))
                except ValueError:
                    print(f"unparseable ttl-expires-at on {instance['InstanceId']}: {expires_raw!r}")
                    continue
                if expires < now:
                    reaped.append(instance["InstanceId"])
                    print(
                        f"reaping {instance['InstanceId']} "
                        f"(run-id={tags.get('run-id', '?')}, expired {expires_raw})"
                    )

    if reaped and os.environ.get("DRY_RUN", "false") != "true":
        ec2.terminate_instances(InstanceIds=reaped)

    return {"reaped": reaped, "dry_run": os.environ.get("DRY_RUN", "false")}
