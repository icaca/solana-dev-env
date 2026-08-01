FROM rust:1.90

ARG SOLANA_VERSION=v3.1.14

RUN apt-get update -y && \
    apt-get install -y \
        pkg-config \
        build-essential \
        libudev-dev \
        clang \
        llvm \
        lld \
        protobuf-compiler \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Rust tools
RUN rustup component add rustfmt

# Install Solana/Agave tools
RUN sh -c "$(curl -sSfL https://release.anza.xyz/$SOLANA_VERSION/install)"

ENV PATH=/root/.local/share/solana/install/active_release/bin:$PATH

COPY shell-exec.sh /bin/shell-exec
RUN chmod +x /bin/shell-exec

WORKDIR /workspace

EXPOSE 8080
EXPOSE 9000
