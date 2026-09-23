#!/bin/sh
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
