#cloud-config
# Runs on the KVM host at boot: pull the lab guest image and define/start it.
# The AMI (built by hyperforge-bakery/packer/kvm-host) already has
# qemu-system-x86, libvirt, virt-install, and the aws cli installed.
#
# --cpu host-passthrough exposes VT-x to the guest so hypervisor products
# (Nutanix AHV/AOS, HPE VME) can run their own VMs one level deeper.

runcmd:
  - systemctl enable --now libvirtd
  - mkdir -p /var/lib/libvirt/images
  - aws s3 cp '${lab_image_s3_uri}' /var/lib/libvirt/images/${guest_name}.qcow2
%{ for idx, size in extra_disk_gb ~}
  - qemu-img create -f qcow2 /var/lib/libvirt/images/${guest_name}-data${idx}.qcow2 ${size}G
%{ endfor ~}
  - |
    virt-install \
      --name ${guest_name} \
      --memory ${guest_memory_mb} \
      --vcpus ${guest_vcpus} \
      --cpu host-passthrough \
      --disk path=/var/lib/libvirt/images/${guest_name}.qcow2,format=qcow2,bus=virtio \
%{ for idx, size in extra_disk_gb ~}
      --disk path=/var/lib/libvirt/images/${guest_name}-data${idx}.qcow2,format=qcow2,bus=virtio \
%{ endfor ~}
      --import \
      --osinfo detect=on,require=off \
      --network network=default,model=virtio \
      --graphics none \
      --noautoconsole
  - touch /var/run/hyperforge-guest-started
