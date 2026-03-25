#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.zst"
DECLARED_HASH="N-V-__8AAPZ7fwBg4JoCzM_0o2A8wxH2hsUUeiU1iuZv53L5"
EXPECTED_BAD_HASH="N-V-__8AADp9fwBUZR8Rf_9U59_LbUKkcR9fzTFYz8I0D5wZ"
MIN_ZIG_VERSION="0.16.0-dev.2905+5d71e3051"

usage() {
    cat <<'EOF'
Create a minimal nested-package repro for Zig's package-fetch hash mismatch bug.

The script proves two behaviors:
1. Direct `zig fetch <url>` returns the declared upstream hash.
2. Nested resolution via `zig build repro` fails with the flattened-hash mismatch.

Optional environment overrides:
  ZIG               Zig executable to use. Default prefers meshy anyzig, then `zig` in PATH.
  KEEP_REPRO_DIR    If set to 1, keep the temporary repro directory after the run.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

zig_cmd() {
    if [[ -n "${ZIG:-}" ]]; then
        printf '%s\n' "$ZIG"
        return
    fi

    if [[ -x /home/bob/meshy-research/.local/anyzig/zig ]]; then
        printf '%s\n' "/home/bob/meshy-research/.local/anyzig/zig"
        return
    fi

    if command -v zig >/dev/null 2>&1; then
        command -v zig
        return
    fi

    printf 'Missing required Zig executable\n' >&2
    exit 1
}

ROOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zig-fetch-hash-mismatch.XXXXXX")"
cleanup() {
    if [[ "${KEEP_REPRO_DIR:-0}" == "1" ]]; then
        printf 'Keeping repro directory: %s\n' "$ROOT_DIR"
        return
    fi
    rm -rf "$ROOT_DIR"
}
trap cleanup EXIT

mkdir -p "$ROOT_DIR/vendor/zstd_repro"

cat >"$ROOT_DIR/build.zig" <<'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.dependency("zstd_repro", .{});
    const step = b.step("repro", "Trigger nested dependency resolution");
    _ = step;
}
EOF

cat >"$ROOT_DIR/build.zig.zon" <<'EOF'
.{
    .name = .zig_fetch_symlink_repro,
    .version = "0.0.0",
    .minimum_zig_version = "0.16.0-dev.2905+5d71e3051",
    .fingerprint = 0x6cea57401166b8bc,
    .dependencies = .{
        .zstd_repro = .{ .path = "vendor/zstd_repro" },
    },
    .paths = .{ "build.zig", "build.zig.zon", "vendor" },
}
EOF

cat >"$ROOT_DIR/vendor/zstd_repro/build.zig" <<'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = std;
    _ = b.dependency("zstd", .{});
}
EOF

cat >"$ROOT_DIR/vendor/zstd_repro/build.zig.zon" <<EOF
.{
    .name = .zstd_repro,
    .version = "0.0.0",
    .minimum_zig_version = "$MIN_ZIG_VERSION",
    .fingerprint = 0x7aeb74faabcf9586,
    .dependencies = .{
        .zstd = .{
            .url = "$UPSTREAM_URL",
            .hash = "$DECLARED_HASH",
        },
    },
    .paths = .{ "build.zig", "build.zig.zon" },
}
EOF

ZIG_BIN="$(zig_cmd)"

printf 'Using Zig executable: %s\n' "$ZIG_BIN"
printf 'Repro directory: %s\n\n' "$ROOT_DIR"

printf '== Direct fetch control ==\n'
direct_hash="$(cd "$ROOT_DIR/vendor/zstd_repro" && "$ZIG_BIN" fetch "$UPSTREAM_URL")"
printf 'Declared hash: %s\n' "$DECLARED_HASH"
printf 'Direct fetch:   %s\n\n' "$direct_hash"

if [[ "$direct_hash" != "$DECLARED_HASH" ]]; then
    printf 'Direct fetch did not return the declared hash\n' >&2
    exit 1
fi

printf '== Nested build repro ==\n'
rm -rf "$ROOT_DIR/zig-cache" "$ROOT_DIR/zig-out" "$ROOT_DIR/zig-pkg" "$ROOT_DIR/vendor/zstd_repro/zig-pkg"

set +e
build_output="$(cd "$ROOT_DIR" && "$ZIG_BIN" build repro 2>&1)"
build_status=$?
set -e

printf '%s\n\n' "$build_output"

if [[ $build_status -eq 0 ]]; then
    printf 'Expected nested build to fail, but it succeeded\n' >&2
    exit 1
fi

if [[ "$build_output" != *"$DECLARED_HASH"* ]]; then
    printf 'Nested build output did not mention the declared hash\n' >&2
    exit 1
fi

if [[ "$build_output" != *"$EXPECTED_BAD_HASH"* ]]; then
    printf 'Nested build output did not mention the expected flattened hash\n' >&2
    exit 1
fi

printf 'Reproduced expected mismatch:\n'
printf '  declared hash: %s\n' "$DECLARED_HASH"
printf '  fetched hash:  %s\n' "$EXPECTED_BAD_HASH"
