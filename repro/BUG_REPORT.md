# Zig Nested Fetch Hash Mismatch Repro

## Suspected cause

The recompression pass walks both files and symlinks:

- <https://codeberg.org/ziglang/zig/src/commit/eec244c5a2ea391d62164c657086472208118672/src/Package/Fetch.zig#L399>

Later it writes entries back out through the regular-file path:

- <https://codeberg.org/ziglang/zig/src/commit/eec244c5a2ea391d62164c657086472208118672/src/Package/Fetch.zig#L440>

That appears to flatten symlinks into plain files in the global cache tarball. When Zig later installs from that cached package, the extracted tree no longer matches the original upstream archive, so nested dependency resolution reports a hash mismatch even though `zig fetch` saved the correct upstream hash.

## Brief repro explanation

This `repro/` folder is intentionally a two-level package setup:

- `repro/build.zig` is a tiny parent package that depends on `zstd_repro`
- `repro/vendor/zstd_repro/` is the nested package where `zig fetch --save=zstd ...` writes the upstream dependency into `build.zig.zon`

The bug only shows up when the parent package resolves that saved URL dependency transitively during `zig build repro`.

## Reproduction

From `repro/` with Zig master on `PATH`:

```bash
cd vendor/zstd_repro
zig fetch --save=zstd https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.zst
cd ../..
zig build repro || true
rm -rf .zig-cache zig-out zig-pkg vendor/zstd_repro/zig-pkg
zig build repro
```

Or run the helper from the repo root:

```bash
scripts/reproduce-fetch-hash-mismatch.sh
```

## Expected result

After `zig fetch --save=zstd ...`, the saved dependency hash should keep matching the upstream tarball during nested `zig build repro`.

## Actual result

`zig fetch --save=zstd ...` saves the upstream hash:

```text
N-V-__8AAPZ7fwBg4JoCzM_0o2A8wxH2hsUUeiU1iuZv53L5
```

But nested `zig build repro` reports:

```text
manifest declares 'N-V-__8AAPZ7fwBg4JoCzM_0o2A8wxH2hsUUeiU1iuZv53L5'
fetched package has 'N-V-__8AADp9fwBUZR8Rf_9U59_LbUKkcR9fzTFYz8I0D5wZ'
```

The second build after deleting `zig-cache`, `zig-out`, `zig-pkg`, and `vendor/zstd_repro/zig-pkg` reproduces the same mismatch.
