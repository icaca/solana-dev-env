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

COPY verify-protobuf.sh /usr/local/bin/verify-protobuf
RUN chmod +x /usr/local/bin/verify-protobuf && verify-protobuf

COPY verify-sbpf-v3.sh /usr/local/bin/verify-sbpf-v3
RUN chmod +x /usr/local/bin/verify-sbpf-v3
# Pre-download the pinned platform tools and verify a real v3 syscall program.
RUN verify-sbpf-v3

COPY shell-exec.sh /bin/shell-exec
RUN chmod +x /bin/shell-exec
WORKDIR /workspace
