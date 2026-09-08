FROM weaveworks/ignite-kernel-builder:dev AS builder

# Set up environment variables
ENV CCACHE_DIR=/ccache       \
    SRC_DIR=/usr/src         \
    DIST_DIR=/dist           \
    LINUX_DIR=/usr/src/linux \
    LINUX_REPO_URL=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
    KBUILD_BUILD_USER=ignite \
    KBUILD_BUILD_HOST=sourcegraph \
    KBUILD_BUILD_VERSION=1

ARG KERNEL_VERSION
ARG KERNEL_SOURCE_COMMIT
ARG KERNEL_EXTRA
# ARCH here is KERNEL_ARCH in the Makefile. It needs to be hardcoded to ARCH for Kconfig to understand
ARG ARCH
ARG GOARCH
ARG ARCH_MAKE_PARAMS

# Fetch the immutable commit behind the desired kernel tag and verify that the
# version and commit supplied by the release configuration agree.
RUN mkdir -p ${SRC_DIR} ${CCACHE_DIR} ${DIST_DIR} && \
    test -n "${KERNEL_SOURCE_COMMIT}" && \
    git init ${LINUX_DIR} && \
    git -C ${LINUX_DIR} remote add origin ${LINUX_REPO_URL} && \
    git -C ${LINUX_DIR} fetch --depth 1 origin ${KERNEL_SOURCE_COMMIT} && \
    git -C ${LINUX_DIR} checkout --detach FETCH_HEAD && \
    test "$(git -C ${LINUX_DIR} rev-parse HEAD)" = "${KERNEL_SOURCE_COMMIT}" && \
    test "$(make -s -C ${LINUX_DIR} kernelversion)" = "${KERNEL_VERSION}" && \
    make -C ${LINUX_DIR} clean && make -C ${LINUX_DIR} mrproper

# Change workdir to run all the build commands from LINUX_DIR.
WORKDIR ${LINUX_DIR}

COPY generated/config-${GOARCH}-${KERNEL_VERSION}${KERNEL_EXTRA} .config

RUN export SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" \
           KBUILD_BUILD_TIMESTAMP="$(git show -s --format=%cI HEAD)" && \
    make ${ARCH_MAKE_PARAMS} EXTRAVERSION=${KERNEL_EXTRA} LOCALVERSION= olddefconfig

RUN export SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" \
           KBUILD_BUILD_TIMESTAMP="$(git show -s --format=%cI HEAD)" && \
	make ${ARCH_MAKE_PARAMS} EXTRAVERSION=${KERNEL_EXTRA} LOCALVERSION= -j"$(nproc)"
RUN mkdir -p /lib/modules

# VMLINUX_PATH is configurable, as the arm64 kernel to be booted by Firecracker is present
# in arch/arm64/boot/Image.
ARG VMLINUX_PATH="vmlinux"
RUN cp ${VMLINUX_PATH} /boot/vmlinux-${KERNEL_VERSION}${KERNEL_EXTRA} && \
	ln -s /boot/vmlinux-${KERNEL_VERSION}${KERNEL_EXTRA} /boot/vmlinux && \
	cp .config /boot/config-${KERNEL_VERSION}${KERNEL_EXTRA}

FROM scratch
ARG KERNEL_VERSION
ARG KERNEL_SOURCE_COMMIT
LABEL org.opencontainers.image.source="https://github.com/sourcegraph/ignite" \
      org.opencontainers.image.version="${KERNEL_VERSION}" \
      org.opencontainers.image.revision="${KERNEL_SOURCE_COMMIT}"
COPY --from=builder /boot /boot
COPY --from=builder /lib/modules /lib/modules
