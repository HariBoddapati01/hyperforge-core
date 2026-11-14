#cloud-config
# Runs on the KubeVirt host at boot. The AMI (hyperforge-bakery/packer/
# kubevirt-host) has k3s installed+enabled and the pinned KubeVirt operator
# manifests + virtctl staged under /opt/hyperforge. The operator is applied
# here rather than at bake time because virt-handler needs /dev/kvm, which
# only exists on the .metal runtime instance.

runcmd:
  - mkdir -p /var/lib/hyperforge/images
  - aws s3 cp '${lab_image_s3_uri}' /var/lib/hyperforge/images/${guest_name}.qcow2
  - chmod 644 /var/lib/hyperforge/images/${guest_name}.qcow2
  # wait for k3s, then install KubeVirt with the HostDisk feature gate
  - |
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    until kubectl get node >/dev/null 2>&1; do sleep 5; done
    kubectl apply -f /opt/hyperforge/kubevirt-operator.yaml
    kubectl apply -f /opt/hyperforge/kubevirt-cr.yaml
    kubectl -n kubevirt patch kubevirt kubevirt --type merge \
      -p '{"spec":{"configuration":{"developerConfiguration":{"featureGates":["HostDisk"]}}}}'
    kubectl -n kubevirt wait kubevirt kubevirt --for=condition=Available --timeout=15m
  - |
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    cat > /var/lib/hyperforge/${guest_name}.yaml <<'MANIFEST'
    apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      name: ${guest_name}
    spec:
      runStrategy: Always
      template:
        spec:
          domain:
            cpu:
              cores: ${guest_vcpus}
            memory:
              guest: ${guest_memory_mb}Mi
            devices:
              disks:
                - name: boot
                  disk:
                    bus: virtio
    %{~ for idx, size in extra_disk_gb }
                - name: data${idx}
                  disk:
                    bus: virtio
    %{~ endfor }
          volumes:
            - name: boot
              hostDisk:
                path: /var/lib/hyperforge/images/${guest_name}.qcow2
                type: Disk
    %{~ for idx, size in extra_disk_gb }
            - name: data${idx}
              hostDisk:
                path: /var/lib/hyperforge/images/${guest_name}-data${idx}.img
                type: DiskOrCreate
                capacity: ${size}Gi
    %{~ endfor }
    MANIFEST
    kubectl apply -f /var/lib/hyperforge/${guest_name}.yaml
    kubectl wait vm ${guest_name} --for=condition=Ready --timeout=20m
  - touch /var/run/hyperforge-guest-started
