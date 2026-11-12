# hyperforge-core

Terraform for ephemeral hypervisor test hosts on AWS. Each CI run provisions a
host, runs the e2e suite against a lab guest VM, and destroys everything.
Companion repos: `hyperforge-bakery` (golden AMIs + lab guest images),
`hyperforge-flows` (CI orchestration).

## Layout

```
modules/
  nested-kvm/    KVM + HPE VME leg: Linux host running libvirt/QEMU guests
  hyperv-metal/  Hyper-V leg: Windows Server bare-metal host
  ttl-reaper/    Lambda safety net that kills expired ephemeral instances
envs/
  test/          Root module invoked per CI run (one leg per state file)
```

## Important: all legs run on `.metal` instances

AWS does **not** support nested virtualization on regular (non-metal) EC2
instances — `/dev/kvm` is simply absent there, and Hyper-V's requirements are
stricter still. Both modules therefore default to `.metal` instance types:

| Leg | Default type | Spot? | Notes |
|-----|-------------|-------|-------|
| kvm / vme | `c6i.metal` | yes (one-time request) | HPE VM Essentials is KVM-based; same host stack |
| hyperv | `m6i.metal` | no | Metal Spot too scarce; interruption wastes ~10 min provision |

If metal pricing becomes the dominant cost, the KVM/VME legs are portable to
GCP (which supports nested KVM on ordinary N2/C2 VMs); the Terraform is
structured so only the module internals would change.

## Cost controls

- Spot one-time requests for the KVM/VME leg.
- Per-run TTL tag (`ttl-expires-at`) on every instance.
- `ttl-reaper` Lambda runs every 15 min and force-terminates anything tagged
  `ephemeral-test=true` past its TTL — independent of CI, so a crashed
  pipeline can't leak a $4+/hr metal box overnight. Deploy it once per
  account (not per run); it ships with `dry_run = true` — flip to `false`
  after checking its CloudWatch logs look right.
- IAM for the reaper is tag-scoped: it can only terminate `ephemeral-test`
  instances.

## State

One state file per run+leg (`runs/<run-id>.tfstate` in the state bucket),
passed via `-backend-config` at init. This is what makes parallel matrix legs
and repeated runs safe — no shared state, no locking contention, and a failed
run's state is inspectable afterwards.

## One-time setup (not in this repo yet)

- S3 buckets: tfstate + golden images
- VPC/subnet/SG for test hosts (SG: egress only; access via SSM, no inbound)
- OIDC role for GitHub Actions (`AWS_CI_ROLE_ARN`)
- Service quota check: `.metal` instances count against "Running On-Demand
  Standard instances" vCPU quotas — c6i.metal is 128 vCPUs. Request quota
  headroom before first run.
- Deploy `modules/ttl-reaper` once: `terraform apply` in a small standalone
  root (or add an `envs/shared`).
