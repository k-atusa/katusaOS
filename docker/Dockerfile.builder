# katusaOS Multi-arch Docker Builder
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    e2fsprogs \
    dosfstools \
    rsync \
    kmod \
    util-linux \
    fdisk \
    ca-certificates \
    curl \
    wget \
    xz-utils \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["/bin/bash"]
