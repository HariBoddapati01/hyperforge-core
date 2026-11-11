#cloud-config
# Runs on the KVM host at boot: pull the lab guest image and define/start it.
# The AMI (built by hv-testbed-images/packer/kvm-host) already has
# qemu-kvm, libvirt, virt-install, and the aws cli installed, and nested
# virtualization verified at bake time.

runcmd:
  - systemctl enable --now libvirtd
  - mkdir -p /var/lib/libvirt/images
  - aws s3 cp '${lab_image_s3_uri}' /var/lib/libvirt/images/${guest_name}.qcow2
  - |
    virt-install \
      --name ${guest_name} \
      --memory ${guest_memory_mb} \
      --vcpus ${guest_vcpus} \
      --disk path=/var/lib/libvirt/images/${guest_name}.qcow2,format=qcow2,bus=virtio \
      --import \
      --os-variant generic \
      --network network=default,model=virtio \
      --graphics none \
      --noautoconsole
  - touch /var/run/hv-testbed-guest-started
