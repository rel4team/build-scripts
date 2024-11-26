FROM debian:bookworm AS build_rel4 

RUN apt-get update -q && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    # for seL4
    gcc-aarch64-linux-gnu \
    python3-dev \
    python3-venv \
    cmake \
    ninja-build \
    device-tree-compiler \
    libxml2-utils \
    qemu-utils \
    qemu-system-arm \
    qemu-efi-aarch64 \
    ipxe-qemu \
    # for bindgen
    libclang-dev \
    # for test script
    python3-pexpect \
    # for hacking
    bash-completion \
    man \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -sSf https://sh.rustup.rs | \
        bash -s -- -y --no-modify-path \
            --default-toolchain nightly-2024-09-01 \
            --component rust-src

ENV PATH=/root/.cargo/bin:$PATH

# the directory where seL4 will be installed
ENV SEL4_INSTALL_DIR=/opt/seL4
# the directory where reL4 will be installed
ENV REL4_INSTALL_DIR=/opt/reL4

RUN set -eux; \
    git clone \
        https://github.com/seL4/seL4.git \
        --config advice.detachedHead=false; \
    cd seL4; \
    git checkout cd6d3b8c25d49be2b100b0608cf0613483a6fffa;

RUN set -eux; \
    cd seL4; \
    python3 -m venv pyenv; \
    export PATH=$(realpath ./pyenv/bin):$PATH; \
    pip install tools/python-deps; \
    cmake \
        -DCROSS_COMPILER_PREFIX=aarch64-linux-gnu- \
        -DCMAKE_INSTALL_PREFIX=$SEL4_INSTALL_DIR \
        -DKernelPlatform=qemu-arm-virt \
        -DKernelArmHypervisorSupport=ON \
        -DKernelVerificationBuild=OFF \
        -DARM_CPU=cortex-a57 \
        -G Ninja \
        -S . \
        -B build; \
    ninja -C build all; \
    ninja -C build install; \
    rm -rf $(pwd);

RUN set -eux; \
    url="https://github.com/seL4/rust-sel4"; \
    rev="1cd063a0f69b2d2045bfa224a36c9341619f0e9b"; \
    common_args="--git $url --rev $rev --root $SEL4_INSTALL_DIR"; \
    CC_aarch64_unknown_none=aarch64-linux-gnu-gcc \
    SEL4_PREFIX=$SEL4_INSTALL_DIR \
        cargo install \
            -Z build-std=core,compiler_builtins \
            -Z build-std-features=compiler-builtins-mem \
            --target aarch64-unknown-none \
            $common_args \
            sel4-kernel-loader; \
    cargo install \
        $common_args \
        sel4-kernel-loader-add-payload;

RUN set -eux; \
    git clone \
        https://github.com/rel4team/mi-dev-integral-rel4.git rel4_kernel -b microkit \
        --config advice.detachedHead=false;
RUN set -eux; \
    git clone \
        https://github.com/rel4team/seL4_c_impl.git \
        --config advice.detachedHead=false -b microkit;
    
COPY kernel-settings-aarch64.cmake .
RUN set -eux; \
    cd rel4_kernel;\
    git pull; \
    python3 -m venv pyenv; \
    export PATH=$(realpath ./pyenv/bin):$PATH; \
    pip install pyyaml pyfdt jinja2 six future ply; \
    rustup install nightly-2024-01-31; \
    rustup default nightly-2024-01-31; \
    rustup target add aarch64-unknown-none-softfloat; \
    cargo build --release --target aarch64-unknown-none-softfloat; \
    cd ../seL4_c_impl; \
    git pull; \
    rm -rf build; \
    cmake \
        -DCROSS_COMPILER_PREFIX=aarch64-linux-gnu- \
        -DCMAKE_INSTALL_PREFIX=$REL4_INSTALL_DIR \
        -C ./kernel-settings-aarch64.cmake \
        -G Ninja \
        -S . \
        -B build; \
    ninja -C build all; \
    ninja -C build install;

RUN set -eux; \
    cp ${SEL4_INSTALL_DIR}/bin/sel4-kernel-loader \
        ${SEL4_INSTALL_DIR}/bin/sel4-kernel-loader-add-payload ${REL4_INSTALL_DIR}/bin;

FROM ubuntu:22.04 AS build_qemu

ARG QEMU_VERSION=8.2.5

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git build-essential gdb-multiarch qemu-system-misc \
    gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu curl autoconf automake autotools-dev curl \
    libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc \
    zlib1g-dev libexpat-dev pkg-config libglib2.0-dev libpixman-1-dev libsdl2-dev libslirp-dev tmux python3 \
    python3-pip ninja-build wget python3-venv python3-dev libclang-dev python3-pexpect bash-completion \
    qemu-utils qemu-system-arm qemu-efi-aarch64 ipxe-qemu cmake

RUN wget https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz && \
    tar xf qemu-${QEMU_VERSION}.tar.xz && \
    cd qemu-${QEMU_VERSION} && \ 
    ./configure --target-list=riscv64-softmmu,riscv64-linux-user && \
    make -j$(nproc) && \
    make install

RUN rm -rf qemu-${QEMU_VERSION} && \
    tar xf qemu-${QEMU_VERSION}.tar.xz && \
    cd qemu-${QEMU_VERSION} && \ 
    ./configure --target-list=aarch64-softmmu,aarch64-linux-user && \
    make -j$(nproc) && \
    make install

FROM ubuntu:22.04 AS rel4_dev

COPY --from=build_qemu /usr/local/bin/* /usr/local/bin

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential cmake ccache ninja-build \
    cmake-curses-gui libxml2-utils ncurses-dev curl git doxygen device-tree-compiler u-boot-tools \
    python3-dev python3-pip python-is-python3 protobuf-compiler python3-protobuf \
    gcc-arm-linux-gnueabi g++-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu g++-riscv64-linux-gnu repo gdb-multiarch libglib2.0-dev zlib1g-dev \
    libpixman-1-dev cpio g++ python3-libarchive-c sudo git build-essential gdb-multiarch \
    qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu curl autoconf automake \
    autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
    gperf libtool patchutils bc zlib1g-dev libexpat-dev pkg-config libglib2.0-dev libpixman-1-dev \
    libsdl2-dev libslirp-dev tmux python3 python3-pip ninja-build wget

RUN pip install --user setuptools sel4-deps aenum pyelftools grpcio_tools pygments

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/bin/riscv/bin:$PATH \
    RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static \
    RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup

RUN curl -L -O https://github.com/yfblock/rel4-docker/releases/download/toolchain/riscv.tar.gz && \
    tar xzvf riscv.tar.gz -C /usr/local/bin && \
    rm riscv.tar.gz

COPY docker_start_user.sh /usr/local/bin

COPY --from=build_qemu /usr/local/share/qemu/* /usr/local/share/qemu/

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y --no-modify-path \
    --default-toolchain nightly-2024-02-01 \
    --component rust-src cargo clippy rust-docs rust-src rust-std rustc rustfmt \
    --target aarch64-unknown-none-softfloat riscv64imac-unknown-none-elf

COPY --from=build_rel4 /opt/seL4/ /opt/seL4/
COPY --from=build_rel4 /opt/reL4/ /opt/reL4/

ENV SEL4_INSTALL_DIR=/opt/seL4 \
    REL4_INSTALL_DIR=/opt/reL4