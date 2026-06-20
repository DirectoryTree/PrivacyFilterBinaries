#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <privacy-filter archive> <model.gguf>" >&2
  exit 1
fi

ARCHIVE="$1"
MODEL="$2"
TEXT="${PF_CLASSIFICATION_TEXT:-Contact John Doe at jdoe@example.com from 555-0100.}"
EXPECTED_TEXT="${PF_EXPECTED_ENTITY_TEXT:-jdoe@example.com}"
THRESHOLD="${PF_CLASSIFICATION_THRESHOLD:-0.5}"

if [[ ! -f "${ARCHIVE}" ]]; then
  echo "Archive does not exist: ${ARCHIVE}" >&2
  exit 1
fi

if [[ ! -f "${MODEL}" ]]; then
  echo "Model does not exist: ${MODEL}" >&2
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

BINARY="${TMPDIR_TEST}/${PACKAGE}/bin/privacy-filter"
SERVE_BINARY="${TMPDIR_TEST}/${PACKAGE}/bin/privacy-filter-serve"

if [[ "${OS}" == "windows" ]]; then
  BINARY="${BINARY}.exe"
  SERVE_BINARY="${SERVE_BINARY}.exe"
fi

if [[ ! -e "${BINARY}" ]]; then
  echo "Binary does not exist: ${BINARY}" >&2
  exit 1
fi

if [[ ! -e "${SERVE_BINARY}" ]]; then
  echo "Serve binary does not exist: ${SERVE_BINARY}" >&2
  exit 1
fi

OUTPUT="$(printf '%s' "${TEXT}" | "${BINARY}" --classify "${MODEL}" "${THRESHOLD}")"

if [[ "${OUTPUT}" != *"${EXPECTED_TEXT}"* ]]; then
  echo "Expected classification output to contain: ${EXPECTED_TEXT}" >&2
  echo "${OUTPUT}" >&2
  exit 1
fi

if [[ "${OUTPUT}" == "[]" || "${OUTPUT}" == $'[\n]' ]]; then
  echo "Expected at least one classified entity." >&2
  echo "${OUTPUT}" >&2
  exit 1
fi

REQUEST="$(printf '{"id":"test","text":"%s","threshold":%s}\n' "${TEXT}" "${THRESHOLD}")"
SERVE_OUTPUT="$(printf '%s' "${REQUEST}" | "${SERVE_BINARY}" "${MODEL}")"

if [[ "${SERVE_OUTPUT}" != *"${EXPECTED_TEXT}"* ]]; then
  echo "Expected serve classification output to contain: ${EXPECTED_TEXT}" >&2
  echo "${SERVE_OUTPUT}" >&2
  exit 1
fi

if [[ "${SERVE_OUTPUT}" == *'"error"'* ]]; then
  echo "Expected serve classification output to be successful." >&2
  echo "${SERVE_OUTPUT}" >&2
  exit 1
fi

printf 'Classification test passed: %s detected in %s\n' "${EXPECTED_TEXT}" "${FILENAME}"
