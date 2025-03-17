FROM public.ecr.aws/docker/library/varnish:7.6.1 AS varnish
FROM varnish AS build_vmod
ENV VMOD_BUILD_DEPS="libcurl4-openssl-dev libpcre3-dev libarchive-dev git cmake build-essential"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install /pkgs/*.deb $VMOD_DEPS $VMOD_BUILD_DEPS; \
    rm -rf /var/lib/apt/lists/*;
RUN set -e; \
    cd /; \
    git clone https://github.com/varnish/libvmod-tinykvm.git; \
    cd libvmod-tinykvm \
    git checkout c74baf190c1827e7e44112bb80f297ca9794d66c; \
    git submodule init; \
    git submodule update;
RUN set -e; \
    cd /libvmod-tinykvm; \
    mkdir -p .build; \
    cd .build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DVARNISH_PLUS=OFF; \
    cmake --build . -j6;

FROM public.ecr.aws/docker/library/rust:1.85-slim-bookworm AS build_rust
RUN rustup target add x86_64-unknown-linux-musl
COPY hello_world /hello_world/
WORKDIR /hello_world
RUN cargo run --release --target x86_64-unknown-linux-musl
RUN cargo run --release --target x86_64-unknown-linux-gnu

FROM varnish
ENV VMOD_RUN_DEPS="libcurl4 libpcre3 libarchive13"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install $VMOD_RUN_DEPS; \
    rm -rf /var/lib/apt/lists/*;
COPY --from=build_vmod /libvmod-tinykvm/.build/libvmod_*.so /usr/lib/varnish/vmods/
COPY --from=build_rust /hello_world/target/x86_64-unknown-linux-musl/release/hello_world /hello_world_rust_musl
COPY --from=build_rust /hello_world/target/x86_64-unknown-linux-gnu/release/hello_world /hello_world_rust_gnu
COPY default.vcl /etc/varnish/default.vcl
USER varnish
