FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b AS builder

ARG GCC_VERSION="gcc-16"

# Install dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
	bc                    \
	bison                 \
	build-essential       \
	ccache                \
	flex                  \
	${GCC_VERSION}        \
	git                   \
	kmod                  \
	libelf-dev            \
	libncurses-dev        \
	libssl-dev            \
	wget                  \
	ca-certificates    && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/${GCC_VERSION} 10

# Install crosscompilers for non-amd64 arches
RUN apt-get install -y --no-install-recommends \
	binutils-multiarch \
	${GCC_VERSION}-aarch64-linux-gnu && \
	ln -s /usr/bin/aarch64-linux-gnu-${GCC_VERSION} /usr/bin/aarch64-linux-gnu-gcc
