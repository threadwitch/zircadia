ARG BASE_IMAGE="${BASE_IMAGE:-}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
ARG KERNEL_VERSION="${KERNEL_VERSION:-6.19.14-ogc1.1.fc44.x86_64}"

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods

FROM scratch AS ctx

COPY build_files /build
COPY system_files /files
COPY cosign.pub /files/usr/share/pki/containers/zircadia.pub

FROM "${BASE_IMAGE}"

# Install kernel
# RUN --mount=type=cache,dst=/var/cache \
#     --mount=type=cache,dst=/var/log \
#     --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
#     --mount=type=bind,from=akmods,src=/rpms/common,dst=/tmp/rpms/common \
#     --mount=type=bind,from=akmods,src=/rpms/kmods,dst=/tmp/rpms/kmods \
#     --mount=type=bind,from=ctx,source=/,target=/ctx \
#     --mount=type=tmpfs,dst=/tmp \
#    /ctx/build/00-kernel-install.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build/01-source-fetch.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build/02-driver-install.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build/03-gaming-install.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build/04-1p-install.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build/05-util-install.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/boot \
    --network=none \
    /ctx/build/99-final-hooks.sh

RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint
