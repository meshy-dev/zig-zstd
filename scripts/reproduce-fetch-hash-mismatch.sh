#!/usr/bin/env bash
set -euo pipefail
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT; mkdir -p "$d/vendor/zstd_repro"
printf '%s\n' 'const std=@import("std");pub fn build(b:*std.Build) void{_ = b.dependency("zstd_repro", .{});_ = b.step("repro","repro");}' >"$d/build.zig"
printf '%s\n' '.{.name=.zig_fetch_symlink_repro,.version="0.0.0",.minimum_zig_version="0.16.0-dev.2905+5d71e3051",.fingerprint=0x6cea57401166b8bc,.dependencies=.{.zstd_repro=.{.path="vendor/zstd_repro"}},.paths=.{"build.zig","build.zig.zon","vendor"}}' >"$d/build.zig.zon"
printf '%s\n' 'const std=@import("std");pub fn build(b:*std.Build) void{_ = std;_ = b.dependency("zstd", .{});}' >"$d/vendor/zstd_repro/build.zig"
printf '%s\n' '.{.name=.zstd_repro,.version="0.0.0",.minimum_zig_version="0.16.0-dev.2905+5d71e3051",.fingerprint=0x7aeb74faabcf9586,.paths=.{"build.zig","build.zig.zon"}}' >"$d/vendor/zstd_repro/build.zig.zon"
(cd "$d/vendor/zstd_repro" && zig fetch --save=zstd https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.zst)
(cd "$d" && zig build repro || true)
rm -rf "$d/zig-cache" "$d/zig-out" "$d/zig-pkg" "$d/vendor/zstd_repro/zig-pkg" && (cd "$d" && zig build repro)
