# Privacy Filter Binaries

Reproducible binary builds for [`localai-org/privacy-filter.cpp`](https://github.com/localai-org/privacy-filter.cpp).

This repository builds and publishes platform-specific `pf-cli` binaries that can be consumed by PHP packages or other language wrappers. The source library is not vendored into this repository; builds clone a pinned upstream ref at build time.

## Artifacts

Release assets are named by operating system and architecture:

```text
privacy-filter-linux-x64.tar.gz
privacy-filter-darwin-x64.tar.gz
privacy-filter-darwin-arm64.tar.gz
privacy-filter-windows-x64.zip
manifest.json
checksums.txt
```

Each archive contains:

```text
bin/privacy-filter
lib/libggml*.dylib   # macOS archives
LICENSE
README.md
build-info.json
```

On Windows, the binary is named `bin/privacy-filter.exe`.

## Build Locally

Prerequisites:

- Git
- CMake 3.21+
- A C++17 compiler

CPU-only local build:

```sh
./scripts/build-local.sh
```

Build a specific upstream ref:

```sh
PRIVACY_FILTER_REF=master ./scripts/build-local.sh
```

The packaged archive is written to `dist/`.

## Test Locally

After building, test the archive:

```sh
./scripts/test-archive.sh dist/privacy-filter-darwin-arm64.tar.gz
```

The test extracts the archive to a temporary directory, verifies the package layout, runs the binary, and checks that macOS archives contain the expected architecture, bundled `libggml` dylibs, and relative rpath.

## Release

Run the `Build binaries` GitHub workflow manually with the upstream ref you want to build. For tagged releases, the workflow uploads archives, `manifest.json`, and `checksums.txt` to the GitHub release.

The PHP package should consume the release `manifest.json`, choose the matching asset for the current platform, verify the checksum, and install the binary into an application-controlled path.

## Scope

The first build target is CPU-only `pf-cli`. Shared-library and GPU builds can be added later as separate artifact families without changing the consumer manifest shape.
