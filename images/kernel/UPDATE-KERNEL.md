# Updating Kernel Images

This document describes the process for adding a new kernel version and making
sure the generated kernel config preserves the options required by Ignite and
Sourcegraph executor Firecracker VMs.

## 1. Add the kernel version

Update `KERNEL_VERSIONS` in `Makefile`:

```make
KERNEL_VERSIONS ?= 5.10.135 6.1.140 6.18.35
```

We primarily target amd64, so ensure `GOARCH` is set to `amd64`:

```bash
export GOARCH=amd64
```

## 2. Add an upstream seed config

Create an upstream config file for the new version:

```bash
cp upstream/config-amd64-6.1.140 upstream/config-amd64-6.18.35
```

If Firecracker publishes a newer recommended base config, use that as the seed
instead.

The file name matters. `upgrade-config.sh` extracts the kernel version from the
trailing field of names like:

```text
upstream/config-amd64-6.18.35
```

## 3. Generate the versioned config

Run the full upgrade flow:

```bash
make upgrade
```

Or generate just one version manually:

```bash
make kernel-builder

./upgrade-config.sh \
  upstream/config-amd64-6.18.35 \
  generated/config-amd64-6.18.35

./patch-config.sh \
  generated/config-amd64-6.18.35 \
  generated/config-amd64-6.18.35 \
  ./config-patches
```

The order is important:

1. `upgrade-config.sh` runs Linux `olddefconfig` for the target kernel.
2. `patch-config.sh` applies Ignite/Sourcegraph-required options last.

Applying patches before `olddefconfig` can cause Kconfig to drop forced options
again.

## 4. Review the generated config

There is intentionally no automated "missing config" gate for every entry in
`config-patches`.

Kernel config symbols are not a stable API across supported kernel versions:
some symbols are renamed, some disappear, and many are silently dropped by
`olddefconfig` unless their Kconfig dependencies are also satisfied.

Treat `config-patches` as a patch recipe, not as a final-config contract. When a
new kernel is added, review the generated config for the capabilities the image
actually needs, then validate those capabilities with a build and smoke test.
Useful targeted checks include:

```bash
rg -n "CONFIG_(VIRTIO|EXT4|OVERLAY|BRIDGE|VETH|NF_NAT|IP_NF|SECCOMP)" \
  generated/config-${GOARCH}-<version>
```

If an expected option is missing after `olddefconfig`, inspect its Kconfig
dependencies in the checked-out kernel source. For example:

```bash
rg -n "config IP_NF_NAT|IP_NF_NAT" ../../bin/cache/linux/<version>/net -S
```

## 5. Build the kernel image

Build only the new version:

```bash
make build-6.18.35
```

This produces:

```text
weaveworks/ignite-kernel:6.18.35-amd64
```

If Sourcegraph expects the `sourcegraph/ignite-kernel` repository name, retag
and import it:

```bash
docker tag \
  weaveworks/ignite-kernel:6.18.35-amd64 \
  sourcegraph/ignite-kernel:6.18.35-amd64

ignite kernel import --runtime docker sourcegraph/ignite-kernel:6.18.35-amd64
```

## 6. Launch a Sourcegraph-shaped VM smoke test

Sourcegraph executor runs Docker inside an Ignite Firecracker VM. Match that
shape when testing:

```bash
VM=sg-kernel-61835-smoke
KERNEL_IMAGE=sourcegraph/ignite-kernel:6.18.35-amd64
VM_IMAGE=sourcegraph/executor-vm:insiders
SANDBOX_IMAGE=sourcegraph/ignite:v0.10.8
WORKDIR=$(mktemp -d)

ignite run "$VM_IMAGE" \
  --runtime docker \
  --network-plugin cni \
  --cpus 2 \
  --memory 2GB \
  --size 20GB \
  --volumes "$WORKDIR:/work" \
  --ssh \
  --name "$VM" \
  --kernel-image "$KERNEL_IMAGE" \
  --kernel-args "console=ttyS0 reboot=k panic=1 pci=off ip=dhcp random.trust_cpu=on i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd" \
  --sandbox-image "$SANDBOX_IMAGE"
```

## 7. Validate the running VM

Check kernel identity and critical config options:

```bash
ignite exec "$VM" -- sh -euxc '
uname -r
cat /proc/cmdline
zcat /proc/config.gz | grep -E "CONFIG_IP_NF_NAT=|CONFIG_IP_NF_IPTABLES_LEGACY=|CONFIG_NETFILTER_XTABLES_LEGACY=|CONFIG_BRIDGE=|CONFIG_VETH=|CONFIG_OVERLAY_FS=|CONFIG_VIRTIO_MMIO=|CONFIG_MEMCG=|CONFIG_SWAP="
'
```

Check Docker inside the VM:

```bash
ignite exec "$VM" -- sh -euxc '
systemctl restart docker
docker info | tee /tmp/docker-info.txt
! grep "WARNING:" /tmp/docker-info.txt
docker run --rm alpine:latest sh -euxc "wget -qO- https://example.com >/dev/null"
'
```

Check `/work`, which is where Sourcegraph executor runs job commands:

```bash
ignite exec "$VM" -- sh -euxc '
echo vm-write-ok > /work/kernel-smoke.txt
docker run --rm -v /work:/work alpine:latest grep -q vm-write-ok /work/kernel-smoke.txt
'
```

## 8. Clean up

```bash
ignite rm -f "$VM"
rm -rf "$WORKDIR"
```

Commit the logically related changes:

- `Makefile` version bump
- `upstream/config-amd64-<version>`
- `generated/config-amd64-<version>`
- any required updates to `config-patches`
- script fixes if needed
