# Contributing to HyperForge

Thanks for your interest! HyperForge is maintained by [@HariBoddapati01](https://github.com/HariBoddapati01); contributions are welcome via fork + pull request.

## How it works

- **Anyone** can open issues and pull requests from a fork.
- **All changes land through a PR** — `main` is protected; even the maintainer merges via PR.
- PRs to this repo must pass the **localtest** suite (the full Terraform roots exercised against a local AWS mock — it runs automatically, costs nothing, and needs no AWS credentials from you).
- The maintainer reviews and squash-merges. Keep PRs focused: one logical change each.

## Before opening a PR

```sh
# runs every profile through apply -> assert -> destroy against a local mock
./localtest/run.sh
```

Also run `terraform fmt -recursive` and, if you touched shell scripts, `shellcheck` them.

## Adding a hypervisor

The most valuable contribution! See "Adding a hypervisor" in the README — it's one `profiles/<name>.yaml` file (plus a Packer host image in [hyperforge-bakery](https://github.com/HariBoddapati01/hyperforge-bakery) if it needs a new host stack). Include the localtest output in your PR description.

## Scope

HyperForge deliberately stays small: profile-driven ephemeral hypervisor hosts with aggressive cost controls. Features that grow the blast radius (long-lived infra, cluster management, product-specific logic) likely belong in a fork or a discussion first — open an issue before building anything large.
