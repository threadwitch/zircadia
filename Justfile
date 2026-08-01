
image := env("IMAGE_FULL", "ghcr.io/threadwitch/zircadia:latest")
filesystem := env("BUILD_FILESYSTEM", "ext4")

# Base images are pinned by digest and kept current by Renovate (.github/renovate.json5).
build:
    # renovate: datasource=docker depName=ghcr.io/zirconium-dev/zirconium
    podman build --no-cache -t zircadia:latest --build-arg BASE_IMAGE=ghcr.io/zirconium-dev/zirconium:latest@sha256:6b2409c9fae5dacc6393e7d635e9252d8a1b0689a19783389caccf215d4414c9 .

build-nvidia:
    # renovate: datasource=docker depName=ghcr.io/zirconium-dev/zirconium-nvidia
    podman build --no-cache -t zircadia-nvidia:latest --build-arg BASE_IMAGE=ghcr.io/zirconium-dev/zirconium-nvidia:latest@sha256:3e95727a851ee12c2532d78c640093e89b2e00251eb251b6bcf1e30860ec8c78 .

iso $image=image:
    #!/usr/bin/env bash
    mkdir -p output
    sudo podman pull "${image}"
    sudo podman run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v "./iso.toml:/config.toml:ro" \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/bootc-image-builder:latest \
        --type iso \
        --rootfs btrfs \
        --use-librepo=True \
        "${image}"

# `iso` pulls a published image and builds from it. `local-iso` instead builds
# the current working tree, stages it into rootful storage (bootc-image-builder
# runs privileged and reads root's container storage, not your rootless storage),
# then runs BIB with --pull=never.
# Build the installer ISO from the local working tree (no registry pull).
local-iso:
    #!/usr/bin/env bash
    set -euo pipefail
    just build
    just rootful localhost/zircadia:latest
    mkdir -p output
    sudo podman run \
        --rm \
        -it \
        --privileged \
        --pull=never \
        --security-opt label=type:unconfined_t \
        -v "./iso.toml:/config.toml:ro" \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/bootc-image-builder:latest \
        --type iso \
        --rootfs btrfs \
        --use-librepo=True \
        localhost/zircadia:latest

rootful $image=image:
    #!/usr/bin/env bash
    podman image scp $USER@localhost::$image root@localhost::$image

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -v "${BUILD_BASE_DIR:-.}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image}}" bootc {{ARGS}}

disk-image $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${BUILD_BASE_DIR:-.}/bootable.img" ] ; then
        fallocate -l 20G "${BUILD_BASE_DIR:-.}/bootable.img"
    fi
    just bootc install to-disk --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe