#!/usr/bin/env bash

set -eu

echo "=== OpenWrt target build environment ==="

: "${ARCH:?ARCH is not set}"
: "${TARGET_CROSS:?TARGET_CROSS is not set}"
: "${STAGING_DIR:?STAGING_DIR is not set}"
: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is not set}"

TARGET_CC="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}gcc"
TARGET_CXX="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}g++"
TARGET_AR="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}ar"
TARGET_RANLIB="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}ranlib"

echo "ARCH          : ${ARCH}"
echo "TARGET_CROSS  : ${TARGET_CROSS}"
echo "STAGING_DIR   : ${STAGING_DIR}"
echo "TOOLCHAIN_DIR : ${TOOLCHAIN_DIR}"

echo
echo "=== Target compiler ==="

for tool in "$TARGET_CC" "$TARGET_CXX" "$TARGET_AR" "$TARGET_RANLIB"; do
    if [[ ! -x "$tool" ]]; then
        echo "Error: target tool not found or not executable: $tool" >&2
        exit 1
    fi

    echo "OK: $tool"
done

echo
echo "=== Target triple ==="
"$TARGET_CC" -dumpmachine

echo
echo "=== Target libraries ==="

for lib in crt1.o crti.o libc.so libgcc_s.so; do
    path="$("$TARGET_CC" -print-file-name="$lib")"

    if [[ ! -e "$path" ]]; then
        echo "Error: target library not found: $lib ($path)" >&2
        exit 1
    fi

    printf '%-12s %s\n' "$lib" "$path"
done

echo
echo "=== Target zlib ==="

TARGET_ZLIB="${STAGING_DIR}/usr/lib/libz.a"

if [[ ! -f "$TARGET_ZLIB" ]]; then
    echo "Error: target zlib not found: $TARGET_ZLIB" >&2
    exit 1
fi

ls -lh "$TARGET_ZLIB"

echo
echo "=== Cross-compile test ==="

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/test.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    puts("OpenWrt cross-compile test");
    return 0;
}
EOF

"$TARGET_CC" "$tmpdir/test.c" -o "$tmpdir/test"

if command -v readelf >/dev/null 2>&1; then
    readelf -h "$tmpdir/test" | grep -E 'Class:|Machine:'
else
    echo "Warning: readelf not found; skipping ELF inspection."
fi

echo
echo "OpenWrt target toolchain check passed."
