
image := env("IMAGE_FULL", "ghcr.io/threadwitch/zircadia:latest")
filesystem := env("BUILD_FILESYSTEM", "ext4")

# Base images are pinned by digest and kept current by Renovate (.github/renovate.json5).
build:
    # renovate: datasource=docker depName=ghcr.io/zirconium-dev/zirconium
    podman build -t zircadia:latest --build-arg BASE_IMAGE=ghcr.io/zirconium-dev/zirconium:latest@sha256:149f7dcdae2f16c0ad872f4f28b971228e623053cb5f7077b8ae4dd6aa74e5da .

build-nvidia:
    # renovate: datasource=docker depName=ghcr.io/zirconium-dev/zirconium-nvidia
    podman build -t zircadia-nvidia:latest --build-arg BUILD_FLAVOR=nvidia --build-arg BASE_IMAGE=ghcr.io/zirconium-dev/zirconium-nvidia:latest@sha256:695d38ef1c28ab5ebbd98a66834b62846c7ccacca8355dfef2fd1b4014f4b70a .

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

quick-iterate:
    #!/usr/bin/env bash
    podman build -t zirconium:latest .
    just rootful
    BUILD_BASE_DIR=/tmp just disk-image