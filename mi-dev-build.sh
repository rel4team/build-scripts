#!/usr/bin/env bash

# Enter current directory
cd "$(dirname "$0")"

# sudo SEL4_PREFIX=/deps/seL4/install \
#     CC=aarch64-linux-gnu-gcc \
#     /root/.cargo/bin/cargo install \ 
#     -Z build-std=core,alloc,compiler_builtins \ 
#     -Z build-std-features=compiler-builtins-mem \
#     --target aarch64-unknown-none \
#     --root /deps --path crates/sel4-kernel-loader  \
#     sel4-kernel-loader
# sudo /root/.cargo/bin/cargo install \
#     --root /deps --path crates/sel4-kernel-loader/add-payload \
#     sel4-kernel-loader-add-payload

cd ../rel4_kernel

make run

cd ../kernel

rm -rf build

cmake \
    -DCROSS_COMPILER_PREFIX=aarch64-linux-gnu- \
    -DCMAKE_INSTALL_PREFIX=../../install \
    -C ./kernel-settings-aarch64.cmake \
    -G Ninja \
    -S . \
    -B build;

ninja -C build all
ninja -C build install

cd ../root-task-demo

make KERNEL=rel4 run
