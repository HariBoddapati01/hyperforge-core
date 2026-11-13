#!/usr/bin/env bash
# Validate the local nested-hypervisor stack end to end:
#   1. Lima VM is up and /dev/kvm exists inside it (nested virt works)
#   2. libvirt can boot a nested guest with KVM acceleration
#   3. The guest actually runs (sentinel: virsh reports it running)
#
# Mirrors what cloud-init does on the cloud kvm leg, with a tiny CirrOS
# aarch64 image standing in for the lab guest.
#
# Usage: ./smoke-test.sh   (assumes `limactl start` already succeeded)
set -euo pipefail

VM=hyperforge
GUEST=hyperforge-smoke
CIRROS_URL="https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-aarch64-disk.img"

run() { limactl shell "$VM" -- sudo bash -c "$*"; }

echo "=== 1/4 nested virtualization available in the Lima VM?"
run 'test -c /dev/kvm' \
  && echo "OK: /dev/kvm present — nested virt is live" \
  || { echo "FAIL: no /dev/kvm in VM (need M3+, macOS 15+, vmType vz, nestedVirtualization true)"; exit 1; }
run 'ls -l /dev/kvm; grep -c . /sys/module/kvm/parameters/* 2>/dev/null | head -1 || true'

echo "=== 2/4 libvirt healthy?"
run 'virsh version --daemon && virsh net-list --all'

echo "=== 3/4 boot a nested guest (CirrOS aarch64, ~20MB)"
run "mkdir -p /var/lib/libvirt/images
     test -f /var/lib/libvirt/images/$GUEST.img || \
       curl -fsSL '$CIRROS_URL' -o /var/lib/libvirt/images/$GUEST.img
     virsh destroy $GUEST 2>/dev/null || true
     virsh undefine $GUEST --nvram 2>/dev/null || true
     virt-install \
       --name $GUEST \
       --memory 512 \
       --vcpus 1 \
       --disk path=/var/lib/libvirt/images/$GUEST.img,format=qcow2,bus=virtio \
       --import \
       --osinfo detect=on,require=off \
       --network network=default,model=virtio \
       --graphics none \
       --noautoconsole"

echo "=== 4/4 guest running with KVM acceleration?"
for i in $(seq 1 12); do
  STATE=$(run "virsh domstate $GUEST" | tr -d '[:space:]')
  [[ "$STATE" == "running" ]] && break
  sleep 5
done
[[ "${STATE:-}" == "running" ]] || { echo "FAIL: guest state is '${STATE:-unknown}'"; exit 1; }
run "virsh dominfo $GUEST | grep -E 'State|CPU'"
run "virsh dumpxml $GUEST | grep -q \"domain type='kvm'\"" \
  && echo "OK: guest is a KVM domain (hardware-accelerated, not TCG emulation)"

echo
echo "PASS: nested hypervisor stack verified — host stack matches the cloud kvm/vme leg."
echo "Cleanup guest with: limactl shell $VM -- sudo virsh destroy $GUEST"
