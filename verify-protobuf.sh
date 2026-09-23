#!/bin/sh
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
