<powershell>
# Runs at boot on the Windows (Hyper-V) host. The AMI (built by
# hyperforge-bakery/packer/hyperv-host) already has the Hyper-V role enabled
# and AWS tooling installed, so this only has to pull and start the guest.

$ErrorActionPreference = "Stop"
$imageDir = "C:\hyperforge\images"
New-Item -ItemType Directory -Force -Path $imageDir | Out-Null

$vhdx = Join-Path $imageDir "${guest_name}.vhdx"
Read-S3Object -BucketName ("${lab_image_s3_uri}" -replace '^s3://([^/]+)/.*','$1') `
              -Key        ("${lab_image_s3_uri}" -replace '^s3://[^/]+/','') `
              -File       $vhdx

if (-not (Get-VMSwitch -Name "hyperforge" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "hyperforge" -SwitchType Internal
}

New-VM -Name "${guest_name}" `
       -MemoryStartupBytes (${guest_memory_mb} * 1MB) `
       -VHDPath $vhdx `
       -Generation 2 `
       -SwitchName "hyperforge"
Set-VMProcessor -VMName "${guest_name}" -Count ${guest_vcpus}
# Expose VT-x to the guest so a hypervisor product can nest its own VMs.
Set-VMProcessor -VMName "${guest_name}" -ExposeVirtualizationExtensions $true

%{ for idx, size in extra_disk_gb ~}
New-VHD -Path (Join-Path $imageDir "${guest_name}-data${idx}.vhdx") -SizeBytes (${size} * 1GB) -Dynamic
Add-VMHardDiskDrive -VMName "${guest_name}" -Path (Join-Path $imageDir "${guest_name}-data${idx}.vhdx")
%{ endfor ~}

Start-VM -Name "${guest_name}"

New-Item -ItemType File -Force -Path "C:\hyperforge\guest-started" | Out-Null
</powershell>
