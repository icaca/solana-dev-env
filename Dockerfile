FROM debian:bookworm-slim

ARG SOLANA_VERSION=v4.0.0
ARG RUST_VERSION=1.95.0
ARG CARGO_BUILD_SBF_VERSION=4.2.0
ARG PLATFORM_TOOLS_VERSION=v1.56

ENV DEBIAN_FRONTEND=noninteractive
ENV PLATFORM_TOOLS_VERSION=${PLATFORM_TOOLS_VERSION}

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        curl ca-certificates git build-essential bzip2 \
        protobuf-compiler libprotobuf-dev && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSfL https://sh.rustup.rs -o /tmp/rustup-init.sh && \
    sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain ${RUST_VERSION} && \
    rm /tmp/rustup-init.sh
ENV PATH="/root/.cargo/bin:${PATH}"

# Remove unused binaries in the installation layer so they do not inflate the image.
RUN curl -sSfL https://release.anza.xyz/${SOLANA_VERSION}/install -o /tmp/agave-install.sh && \
    sh /tmp/agave-install.sh && rm /tmp/agave-install.sh && \
    SOLANA_BIN=/root/.local/share/solana/install/active_release/bin && \
    rm -f ${SOLANA_BIN}/agave-install ${SOLANA_BIN}/agave-install-init \
        ${SOLANA_BIN}/agave-ledger-tool ${SOLANA_BIN}/cargo-test-sbf \
        ${SOLANA_BIN}/solana-test-validator

# Prefer the pinned builder; keep its native build dependencies out of the final layer.
ENV PATH="/root/.cargo/bin:/root/.local/share/solana/install/active_release/bin:${PATH}"
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev && \
    cargo install cargo-build-sbf --version ${CARGO_BUILD_SBF_VERSION} --locked && \
    rm -f /root/.cargo/bin/cargo-test-sbf && \
    apt-get purge -y --auto-remove pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/* /root/.cargo/registry

# Preload the toolchain and verify protobuf imports and SBPF v3 during the build.
RUN <<'CHECKS'
set -eu

protoc --version
test -r /usr/include/google/protobuf/timestamp.proto
proto_dir=$(mktemp -d /tmp/protobuf-smoke.XXXXXX)
cat > "$proto_dir/smoke.proto" <<'PROTO'
syntax = "proto3";
import "google/protobuf/timestamp.proto";
message Smoke {
  google.protobuf.Timestamp timestamp = 1;
}
PROTO
# Match build.rs: only the project include directory is passed explicitly.
protoc --proto_path="$proto_dir" --include_imports \
    --descriptor_set_out="$proto_dir/smoke.pb" "$proto_dir/smoke.proto"
test -s "$proto_dir/smoke.pb"
echo "Protobuf compiler and standard Timestamp import check passed"
set -eu

test "$(command -v cargo-build-sbf)" = /root/.cargo/bin/cargo-build-sbf
solana --version
rustc --version
cargo build-sbf --version

smoke_dir=$(mktemp -d /tmp/sbpf-v3-smoke.XXXXXX)
mkdir "$smoke_dir/src"
cat > "$smoke_dir/Cargo.toml" <<'TOML'
[package]
name = "sbpf-v3-smoke"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
solana-define-syscall = "=2.3.0"

[profile.release]
panic = "abort"
TOML
cat > "$smoke_dir/src/lib.rs" <<'RUST'
#![no_std]

#[no_mangle]
pub extern "C" fn entrypoint(_input: *mut u8) -> u64 {
    let message = b"SBPF v3 smoke";
    unsafe {
        solana_define_syscall::definitions::sol_log_(message.as_ptr(), message.len() as u64);
    }
    0
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
RUST

cargo build-sbf --manifest-path "$smoke_dir/Cargo.toml" \
    --tools-version "${PLATFORM_TOOLS_VERSION:?}" --arch v3
program="$smoke_dir/target/deploy/sbpf_v3_smoke.so"
readelf --file-header "$program"
readelf --file-header "$program" | awk '/Flags:/ { if ($2 == "0x3") v3 = 1 } END { exit !v3 }'
echo "SBPF v3 syscall compilation and ELF check passed: $program"
CHECKS

COPY shell-exec.sh /bin/shell-exec
RUN chmod +x /bin/shell-exec
WORKDIR /workspace
