# Kernel Images

These kernel OCI images contain the kernel binary (at `/boot/vmlinux`) and supporting modules (in `/lib/modules`)
for guest VMs ran by Ignite.

## Building the Kernel Images

```console
$ make
```

## Versions

All LTS versions starting from 4.14 and above are supported by the Ignite team.
This means in practice:

- 4.14.x
- 4.19.x
- 5.4.x
- 5.10.x
- 6.1.x

We also publish stable channel kernels, but they are not the default.

- 5.14.x

The exact patch versions may be found in the [Makefile](Makefile).
The available versions exist in the [stable kernel git tree](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/refs/).
Each version in the Makefile is paired with the immutable commit behind its
stable tag. The build verifies both that commit and the kernel's reported
version, and records the commit in the OCI revision label.

## Upgrading to a new kernel version

The kernel Makefile has an `upgrade` command that will generate patched kernel configs for each specific version in `KERNEL_VERSIONS`.

The Linux kernel source is checked out in a build container for each target
version. Each Firecracker-recommended seed in `upstream/` is patched with the
Ignite-specific `config-patches`, then Linux `olddefconfig` resolves its Kconfig
dependencies and writes the result to `generated/` for the matching build.

Run:

```console
$ make upgrade
```

after you've upgraded the values in the Makefile.

## Kernel Config Parameters we care about

Some options to the kernel are specifically important for making guest software work.

Please see: [config-patches](config-patches) for what kernel configs we've changed.
The base kernel config is the MicroVM-optimized config file from the Firecracker team.
Versioned copies are stored in `upstream/`. The 6.1 seeds come from Firecracker
v1.12.0's `resources/guest_configs` directory. Firecracker cautions that those
configs target its Amazon Linux kernel, so `olddefconfig`, the Ignite patches,
and a boot test are required when using them with upstream stable Linux.
The amd64 seed is copied from Firecracker commit
`15e7490687368f20b572fe045fe377df3df54f32` (the peeled v1.12.0 tag).

The Sourcegraph release workflow currently publishes amd64 images only. Arm64
config and build support remain in the repository, but arm64 must not be added
to a manifest until its build and Firecracker boot test are restored.
