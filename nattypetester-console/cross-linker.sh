#!/bin/bash

echo "=== cross-linker debug ===" >&2
echo "BASH_VERSION=${BASH_VERSION:-unset}" >&2
echo "argv0=$0" >&2
echo "shell=$-" >&2

set -euo pipefail

: "${TARGET_CC:?TARGET_CC is not set}"

args=()

for arg in "$@"; do
    case "${arg}" in
        --target=*)
            echo "[cross-linker] Skip Clang target option: ${arg}" >&2
            ;;
        *)
            args+=("${arg}")
            ;;
    esac
done

echo "[cross-linker] Compiler: ${TARGET_CC}" >&2
echo "[cross-linker] Arguments:" >&2

printf '  %q\n' "${args[@]}" >&2

echo "[cross-linker] GCC version:" >&2
"${TARGET_CC}" --version >&2

echo "[cross-linker] Executing linker..." >&2

exec "${TARGET_CC}" -v "${args[@]}"
