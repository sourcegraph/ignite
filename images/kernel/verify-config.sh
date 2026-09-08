#!/usr/bin/env bash

set -euo pipefail

config=${1:?usage: verify-config.sh CONFIG}

# This is an amd64 runtime contract, not a copy of an upstream defconfig:
# - Firecracker's v1.12.0 x86_64 6.1 guest config supplies the hypervisor baseline.
# - Ignite's kernel command line and SendCtrlAltDel support require the boot devices.
# - Sourcegraph executor requires the filesystems, isolation, and networking used by
#   Docker inside the guest. Keep the rationale alongside each group when adding
#   symbols; config-patches is the recipe, while this checks the resolved config.
required=(
    # Firecracker x86_64 boot and virtio devices.
    ACPI KVM_GUEST VIRTIO_BLK VIRTIO_MMIO VIRTIO_MMIO_CMDLINE_DEVICES VIRTIO_NET
    DEVTMPFS DEVTMPFS_MOUNT EXT4_FS SERIAL_8250 SERIAL_8250_CONSOLE

    # Ignite soft shutdown through Firecracker's SendCtrlAltDel action.
    INPUT_KEYBOARD KEYBOARD_ATKBD SERIO_I8042

    # Guest userspace and Sourcegraph executor's nested Docker workloads.
    PROC_FS SYSFS TMPFS BRIDGE VETH OVERLAY_FS CFS_BANDWIDTH MEMCG USER_NS
    BPF_SYSCALL CGROUP_BPF SECCOMP SECCOMP_FILTER WIREGUARD VXLAN

    # Make the resolved config inspectable from inside a running guest.
    IKCONFIG IKCONFIG_PROC
)

for symbol in "${required[@]}"; do
    if ! grep -qx "CONFIG_${symbol}=y" "${config}"; then
        echo "${config}: required CONFIG_${symbol}=y is missing" >&2
        exit 1
    fi
done

grep -qx '# CONFIG_LOCALVERSION_AUTO is not set' "${config}" || {
    echo "${config}: CONFIG_LOCALVERSION_AUTO must be disabled" >&2
    exit 1
}

grep -qx '# CONFIG_MODULES is not set' "${config}" || {
    echo "${config}: CONFIG_MODULES must be disabled because the OCI image contains no modules" >&2
    exit 1
}

echo "${config}: Firecracker/Ignite config contract verified"
