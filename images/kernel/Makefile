SHELL:=/bin/bash

# Set the command for running `docker`
# -- allows user to override for things like sudo usage or container images
DOCKER := docker

REGISTRY?=weaveworks
IMAGE_NAME?=${REGISTRY}/ignite-kernel
KERNEL_BUILDER_NAME=weaveworks/ignite-kernel-builder

# Check https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/refs/ for updates
KERNEL_VERSIONS ?= 5.10.135 6.1.140 6.18.35 # If you update this, please keep the .github/workflows/release-kernel-images.yml matrix up to date
GOARCH?=amd64
GOARCH_LIST = amd64 # arm64

ifeq ($(GOARCH),amd64)
KERNEL_ARCH=x86
VMLINUX_PATH=vmlinux
DOCKER_PLATFORM=linux/amd64
endif
ifeq ($(GOARCH),arm64)
ARCH_MAKE_PARAMS="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
KERNEL_ARCH=arm64
VMLINUX_PATH=arch/arm64/boot/Image
DOCKER_PLATFORM=linux/arm64
endif

all: build

kernel-builder:
	$(DOCKER) build --platform $(DOCKER_PLATFORM) -t ${KERNEL_BUILDER_NAME}:dev \
		-f builder/Dockerfile .

upgrade: kernel-builder
	mkdir -p upstream generated
	for upstream in upstream/*; do \
		config="$$(basename $$upstream)"; \
		./patch-config.sh upstream/$${config} generated/$${config} ./config-patches; \
		./upgrade-config.sh generated/$${config} generated/$${config}; \
	done

build: $(addprefix build-,$(KERNEL_VERSIONS))
build-%: kernel-builder
	$(DOCKER) build --platform $(DOCKER_PLATFORM) -t $(IMAGE_NAME):$*-${GOARCH} \
		--build-arg KERNEL_VERSION=$* \
		--build-arg ARCH=${KERNEL_ARCH} \
		--build-arg GOARCH=${GOARCH} \
		--build-arg ARCH_MAKE_PARAMS=${ARCH_MAKE_PARAMS} \
		--build-arg VMLINUX_PATH=${VMLINUX_PATH} .

push: $(addprefix push-,$(KERNEL_VERSIONS))
push-%:
	../../hack/push-manifest-list.sh $(IMAGE_NAME):$* $(GOARCH_LIST)

pre-release: $(addprefix pre-release-,$(GOARCH_LIST))
pre-release-%:
	$(MAKE) GOARCH=$* build

release: pre-release
	$(MAKE) push
