#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_REPO="${PRIVACY_FILTER_REPO:-https://github.com/localai-org/privacy-filter.cpp}"
UPSTREAM_REF="${PRIVACY_FILTER_REF:-master}"

for command in git cmake; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Missing required command: ${command}" >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux) OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64) ARCH="x64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

BUILD_ROOT="${ROOT_DIR}/.build"
SOURCE_DIR="${BUILD_ROOT}/privacy-filter.cpp"
BUILD_DIR="${SOURCE_DIR}/build"
PACKAGE_NAME="privacy-filter-${OS}-${ARCH}"
PACKAGE_DIR="${ROOT_DIR}/dist/${PACKAGE_NAME}"

rm -rf "${SOURCE_DIR}" "${PACKAGE_DIR}"
mkdir -p "${BUILD_ROOT}" "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/lib" "${ROOT_DIR}/dist"

git clone --recursive "${UPSTREAM_REPO}" "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" checkout "${UPSTREAM_REF}"
git -C "${SOURCE_DIR}" submodule update --init --recursive

CMAKE_ARGS=(
  -S "${SOURCE_DIR}"
  -B "${BUILD_DIR}"
  -DCMAKE_BUILD_TYPE=Release
  -DPF_BUILD_TESTS=OFF
  -DPF_BUILD_TOOLS=ON
  -DGGML_NATIVE=OFF
)

if [[ "${OS}" == "darwin" ]]; then
  CMAKE_OSX_ARCH="${ARCH}"
  if [[ "${ARCH}" == "x64" ]]; then
    CMAKE_OSX_ARCH="x86_64"
  fi

  CMAKE_ARGS+=("-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCH}")
fi

cmake "${CMAKE_ARGS[@]}"

cmake --build "${BUILD_DIR}" --config Release --target pf-cli -j

if [[ "${OS}" == "windows" ]]; then
  cp "${BUILD_DIR}/pf-cli.exe" "${PACKAGE_DIR}/bin/privacy-filter.exe"
else
  cp "${BUILD_DIR}/pf-cli" "${PACKAGE_DIR}/bin/privacy-filter"
  chmod +x "${PACKAGE_DIR}/bin/privacy-filter"
fi

if [[ "${OS}" == "darwin" ]]; then
  find "${BUILD_DIR}/ggml/src" -name 'libggml*.dylib' -maxdepth 3 -exec cp -P {} "${PACKAGE_DIR}/lib" \;

  for rpath in \
    "${BUILD_DIR}/ggml/src" \
    "${BUILD_DIR}/ggml/src/ggml-blas" \
    "${BUILD_DIR}/ggml/src/ggml-metal"; do
    install_name_tool -delete_rpath "${rpath}" "${PACKAGE_DIR}/bin/privacy-filter" 2>/dev/null || true
  done

  install_name_tool -add_rpath "@loader_path/../lib" "${PACKAGE_DIR}/bin/privacy-filter"
fi

if [[ "${OS}" == "linux" ]]; then
  if ! command -v patchelf >/dev/null 2>&1; then
    echo "Missing required command for Linux packaging: patchelf" >&2
    exit 1
  fi

  find "${BUILD_DIR}/ggml/src" -maxdepth 3 -name 'libggml*.so*' -exec cp -P {} "${PACKAGE_DIR}/lib" \;
  patchelf --set-rpath '$ORIGIN/../lib' "${PACKAGE_DIR}/bin/privacy-filter"
fi

cp "${SOURCE_DIR}/LICENSE" "${PACKAGE_DIR}/LICENSE"
cp "${SOURCE_DIR}/README.md" "${PACKAGE_DIR}/README.md"

UPSTREAM_SHA="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
cat > "${PACKAGE_DIR}/build-info.json" <<JSON
{
  "name": "${PACKAGE_NAME}",
  "upstreamRepository": "${UPSTREAM_REPO}",
  "upstreamRef": "${UPSTREAM_REF}",
  "upstreamCommit": "${UPSTREAM_SHA}",
  "os": "${OS}",
  "arch": "${ARCH}",
  "cpuOnly": true
}
JSON

(
  cd "${ROOT_DIR}/dist"
  if [[ "${OS}" == "windows" ]]; then
    zip -qr "${PACKAGE_NAME}.zip" "${PACKAGE_NAME}"
  else
    tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}"
  fi
)

echo "Built ${ROOT_DIR}/dist/${PACKAGE_NAME}.*"
