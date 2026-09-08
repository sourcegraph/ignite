#!/usr/bin/env bash

KERNEL_BUILDER_IMAGE=weaveworks/ignite-kernel-builder:dev
LINUX_REPO_URL=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

DOCKER_TTY="${DOCKER_TTY:+"-t"}"

if [[ $# != 2 ]]; then
    echo "Usage: $0 [FROM] [TO]"
    exit 1
fi

FROM=$1
TO=$2
VERSION="$(echo ${TO} | rev | cut -d- -f1 | rev)"  # Extracts the trailing hyphenated field (ex: ./generated/config-amd64-6.1.187)
ARCH=$(echo ${TO} | cut -d- -f2)

# Only set the extra flag for non-amd64 arches
if [[ ${ARCH} != amd64 ]]; then
    ARCH_PARAMETER="-e ARCH=${ARCH}"
fi

if [[ ${FROM} != ${TO} ]]; then
    cp ${FROM} ${TO}
fi

CACHE="$(pwd)/../../bin/cache"
mkdir -p "${CACHE}/linux/"
docker run --rm -i ${DOCKER_TTY} \
    -u "$(id -u):$(id -g)" \
    ${ARCH_PARAMETER} \
    -v "$(pwd)/${TO}":/tmp/.config \
    -v "${CACHE}/linux/":/linux/ \
    -w /linux \
    ${KERNEL_BUILDER_IMAGE} /bin/bash -c "
        set -xe
        test -d ./${VERSION} || git clone --depth 1 --branch v${VERSION} ${LINUX_REPO_URL} ./${VERSION}
        cd ./${VERSION}
        cp /tmp/.config .config
        make EXTRAVERSION="" LOCALVERSION= olddefconfig
        cp .config /tmp/.config"
