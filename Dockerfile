FROM rust:1.86

ARG SOLANA_VERSION=v2.1.20
ARG ANCHOR_VERSION=v0.31.1

RUN apt-get update -y 
RUN apt-get upgrade -y 
RUN apt-get install -y pkg-config build-essential libudev-dev clang
RUN rustup component add rustfmt clippy

RUN sh -c "$(curl -sSfL https://release.anza.xyz/$SOLANA_VERSION/install)"
ENV PATH=/root/.local/share/solana/install/active_release/bin:$PATH

RUN cargo install --git https://github.com/coral-xyz/anchor --tag $ANCHOR_VERSION anchor-cli --locked

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs

RUN npm install --global yarn

COPY shell-exec.sh /bin/shell-exec
RUN chmod +x /bin/shell-exec

EXPOSE 8080
EXPOSE 9000

WORKDIR workspace/