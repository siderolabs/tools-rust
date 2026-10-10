#!/bin/sh
# Generate rust's bootstrap.toml for the rustc build.
#
# The build always runs on the amd64 worker (the rustc package pins
# buildPlatform: linux/amd64), so BUILD is always x86_64-*. The requested target
# platform drives ARCH: x86_64 -> native amd64-host rustc, aarch64 -> cross-built
# aarch64-host rustc.
set -eu

BUILD_ARCH="${BUILD%%-*}"                       # x86_64 (build platform)
RUST_BUILD="${BUILD_ARCH}-unknown-linux-musl"
RUST_TARGET="${ARCH}-unknown-linux-musl"        # target

cat <<EOF
[build]
build = "${RUST_BUILD}"
host = ["${RUST_TARGET}"]
target = ["${RUST_TARGET}"]
rustc = "/bootstrap/usr/bin/rustc"
cargo = "/bootstrap/usr/bin/cargo"
# This is the previous release's source-built compiler, not an in-tree rebuild.
# Keep stage0 bootstrap cfg/features enabled for the N-1 seed.
local-rebuild = false
docs = false
vendor = true
extended = true
tools = ["cargo"]

[install]
prefix = "/usr"
sysconfdir = "/etc"

[rust]
channel = "stable"
lld = false
llvm-tools = false

[llvm]
link-shared = true
EOF

# The build platform (x86_64) toolchain is always needed: it is the `build`
# triple (and the host/target for a native amd64 build). Point it at the amd64
# tools LLVM so x.py never falls back to building LLVM from source (which would
# need ninja). Without this block a cross build fails with "Couldn't find ninja".
cat <<EOF

[target.x86_64-unknown-linux-musl]
llvm-config = "/usr/bin/llvm-config"
cc = "clang"
cxx = "clang++"
ar = "llvm-ar"
ranlib = "llvm-ranlib"
linker = "clang"
musl-root = "/usr"
crt-static = false
EOF

if [ "${ARCH}" = "aarch64" ]; then
	# Cross target: aarch64 host, linked against the prebuilt arm64 libLLVM (its
	# llvm-config is represented by the native shim), compiled/linked with the multi-target
	# clang via wrappers that add --target/--sysroot.
	cat <<EOF

[target.aarch64-unknown-linux-musl]
llvm-config = "/usr/bin/aarch64-llvm-config"
cc = "/usr/bin/aarch64-clang"
cxx = "/usr/bin/aarch64-clang++"
ar = "llvm-ar"
ranlib = "llvm-ranlib"
linker = "/usr/bin/aarch64-clang"
musl-root = "/sysroots/aarch64/usr"
crt-static = false
EOF
fi
