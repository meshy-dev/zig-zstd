#!/usr/bin/env bash
set -euo pipefail
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
cp -R "$(dirname "$0")/../repro/." "$d"
(cd "$d/vendor/zstd_repro" && zig fetch --save=zstd https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.zst)
(cd "$d" && zig build repro || true)
rm -rf "$d"/.zig-cache "$d"/zig-out "$d"/zig-pkg "$d"/vendor/zstd_repro/zig-pkg
(cd "$d" && zig build repro)
