FROM debian:bookworm-slim

ARG SOLANA_VERSION=v3.1.14

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    build-essential \
    pkg-config \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/*


# Minimal host cargo
# Only used for:
# - cargo metadata
# - cargo subcommand dispatch
RUN curl https://sh.rustup.rs -sSf | sh -s -- \
    -y \
    --profile minimal

ENV PATH="/root/.cargo/bin:$PATH"


# Install Solana / Agave tools
RUN sh -c "$(curl -sSfL https://release.anza.xyz/${SOLANA_VERSION}/install)"


ENV PATH="/root/.local/share/solana/install/active_release/bin:$PATH"


# Remove unused Solana tools
RUN SOLANA_BIN=/root/.local/share/solana/install/active_release/bin && \
    rm -f \
    ${SOLANA_BIN}/agave-install \
    ${SOLANA_BIN}/agave-install-init \
    ${SOLANA_BIN}/agave-ledger-tool \
    ${SOLANA_BIN}/cargo-test-sbf \
    ${SOLANA_BIN}/solana-test-validator


# Pre-download SBF platform tools
# Avoid first container startup download
RUN mkdir -p /tmp/sbf-test && \
    cd /tmp/sbf-test && \
    cargo init && \
    cargo build-sbf && \
    rm -rf /tmp/sbf-test


COPY shell-exec.sh /bin/shell-exec
RUN chmod +x /bin/shell-exec


WORKDIR /workspace
