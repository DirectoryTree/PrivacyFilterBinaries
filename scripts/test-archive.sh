#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <privacy-filter archive>" >&2
  exit 1
fi

ARCHIVE="$1"

if [[ ! -f "${ARCHIVE}" ]]; then
  echo "Archive does not exist: ${ARCHIVE}" >&2
  exit 1
fi

FILENAME="$(basename "${ARCHIVE}")"
PACKAGE="${FILENAME}"
PACKAGE="${PACKAGE%.tar.gz}"
PACKAGE="${PACKAGE%.zip}"

if [[ ! "${PACKAGE}" =~ ^privacy-filter-(linux|darwin|windows)-(x64|arm64)$ ]]; then
  echo "Unexpected archive name: ${FILENAME}" >&2
  exit 1
fi

OS="${BASH_REMATCH[1]}"
ARCH="${BASH_REMATCH[2]}"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

case "${FILENAME}" in
  *.tar.gz)
    tar -xzf "${ARCHIVE}" -C "${TMPDIR_TEST}"
    ;;
  *.zip)
    unzip -q "${ARCHIVE}" -d "${TMPDIR_TEST}"
    ;;
  *)
    echo "Unsupported archive extension: ${FILENAME}" >&2
    exit 1
    ;;
esac

PACKAGE_DIR="${TMPDIR_TEST}/${PACKAGE}"
BINARY="${PACKAGE_DIR}/bin/privacy-filter"

if [[ "${OS}" == "windows" ]]; then
  BINARY="${BINARY}.exe"
fi

for required in "${PACKAGE_DIR}/LICENSE" "${PACKAGE_DIR}/README.md" "${PACKAGE_DIR}/build-info.json" "${BINARY}"; do
  if [[ ! -e "${required}" ]]; then
    echo "Missing expected package file: ${required}" >&2
    exit 1
  fi
done

if [[ "${OS}" != "windows" && ! -x "${BINARY}" ]]; then
  echo "Binary is not executable: ${BINARY}" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "${PACKAGE_DIR}/build-info.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    info = json.load(handle)

for key in ["name", "upstreamRepository", "upstreamRef", "upstreamCommit", "os", "arch", "cpuOnly"]:
    if key not in info:
        raise SystemExit(f"Missing build-info key: {key}")
PY
fi

set +e
OUTPUT="$("${BINARY}" 2>&1)"
CODE=$?
set -e

if [[ "${CODE}" -ne 2 ]]; then
  echo "Expected no-argument binary invocation to exit 2, got ${CODE}" >&2
  echo "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"usage: pf-cli --info <model.gguf>"* ]]; then
  echo "Expected usage output was not present." >&2
  echo "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OS}" == "darwin" ]]; then
  if ! command -v file >/dev/null 2>&1; then
    echo "Missing required command for macOS archive test: file" >&2
    exit 1
  fi

  FILE_OUTPUT="$(file "${BINARY}")"

  case "${ARCH}" in
    arm64)
      [[ "${FILE_OUTPUT}" == *"arm64"* ]] || {
        echo "Expected arm64 binary, got: ${FILE_OUTPUT}" >&2
        exit 1
      }
      ;;
    x64)
      [[ "${FILE_OUTPUT}" == *"x86_64"* ]] || {
        echo "Expected x86_64 binary, got: ${FILE_OUTPUT}" >&2
        exit 1
      }
      ;;
  esac

  if [[ ! -d "${PACKAGE_DIR}/lib" ]]; then
    echo "Missing bundled macOS lib directory." >&2
    exit 1
  fi

  if ! find "${PACKAGE_DIR}/lib" -maxdepth 1 -name 'libggml*.dylib' | grep -q .; then
    echo "Missing bundled ggml dylibs." >&2
    exit 1
  fi

  if command -v otool >/dev/null 2>&1; then
    if ! otool -l "${BINARY}" | grep -q '@loader_path/../lib'; then
      echo "Missing @loader_path/../lib rpath." >&2
      exit 1
    fi

    if otool -l "${BINARY}" | grep -q '/.build/privacy-filter.cpp/build'; then
      echo "Binary still contains build-directory rpaths." >&2
      exit 1
    fi
  fi
fi

if [[ "${OS}" == "linux" ]]; then
  if [[ ! -d "${PACKAGE_DIR}/lib" ]]; then
    echo "Missing bundled Linux lib directory." >&2
    exit 1
  fi

  if ! find "${PACKAGE_DIR}/lib" -maxdepth 1 -name 'libggml*.so*' | grep -q .; then
    echo "Missing bundled ggml shared objects." >&2
    exit 1
  fi

  if command -v readelf >/dev/null 2>&1; then
    DYNAMIC_SECTION="$(readelf -d "${BINARY}")"

    if [[ "${DYNAMIC_SECTION}" != *'$ORIGIN/../lib'* ]]; then
      echo 'Missing $ORIGIN/../lib rpath.' >&2
      exit 1
    fi

    if [[ "${DYNAMIC_SECTION}" == *'/.build/privacy-filter.cpp/build'* ]]; then
      echo "Binary still contains build-directory rpaths." >&2
      exit 1
    fi
  fi
fi

printf 'Archive test passed: %s\n' "${FILENAME}"
