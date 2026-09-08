# katusaOS Multi-arch Docker Builder (Alpine Linux base)
FROM alpine:3.20

RUN apk update && apk add --no-cache \
    apk-tools-static \
    qemu-aarch64 \
    qemu-x86_64 \
    e2fsprogs \
    dosfstools \
    bash \
    coreutils \
    util-linux \
    curl \
    wget \
    ca-certificates \
    rsync \
    shadow \
    tar \
    xz \
    grub-efi \
    parted \
    mtools \
    xorriso

WORKDIR /workspace

CMD ["/bin/bash"]
