#!/bin/bash

set -eu

echo "=== Build environment ==="
env | grep -E '^(ARCH|TARGET_CROSS|TARGET_CC|STAGING_DIR|TOOLCHAIN_DIR)=' || true

: "${STAGING_DIR:?STAGING_DIR is not set}"
: "${TARGET_CROSS:?TARGET_CROSS is not set}"
: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is not set}"

TARGET_CC="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}gcc"

echo "=== export CC CXX AR RANLIB ==="
export CC="$TOOLCHAIN_DIR/bin/${TARGET_CROSS}gcc"
export CXX="$TOOLCHAIN_DIR/bin/${TARGET_CROSS}g++"
export AR="$TOOLCHAIN_DIR/bin/${TARGET_CROSS}ar"
export RANLIB="$TOOLCHAIN_DIR/bin/${TARGET_CROSS}ranlib"

echo "=== Native tools ==="
for tool in "$CC" "$CXX" "$AR" "$RANLIB"; do
    test -x "$tool" && echo "OK: $tool" || echo "MISSING: $tool"
done

echo "=== Linker ==="
"$CC" -print-prog-name=ld

echo "=== Objcopy ==="
"$CC" -print-prog-name=objcopy

echo "=== Strip ==="
"$CC" -print-prog-name=strip

echo "=== Target zlib ==="
file "$STAGING_DIR/usr/lib/libz.a"