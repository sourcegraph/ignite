#!/usr/bin/env bash

set -euo pipefail

config=${1:?usage: verify-config.sh CONFIG}

required=(
    BPF_SYSCALL BRIDGE CFS_BANDWIDTH CGROUP_BPF DEVTMPFS DEVTMPFS_MOUNT
    EXT4_FS IKCONFIG IKCONFIG_PROC INPUT_KEYBOARD KEYBOARD_ATKBD MEMCG
    OVERLAY_FS PCI PROC_FS SECCOMP SECCOMP_FILTER SERIAL_8250
    SERIAL_8250_CONSOLE SYSFS TMPFS USER_NS VETH VIRTIO_BLK VIRTIO_MMIO
    VIRTIO_MMIO_CMDLINE_DEVICES VIRTIO_NET WIREGUARD VXLAN
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
