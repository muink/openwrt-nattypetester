#!/bin/bash

set -eu

echo "=== Build environment ==="
env | grep -E '^(ARCH|TARGET_CROSS|TARGET_CC|STAGING_DIR|TOOLCHAIN_DIR)=' || true

: "${STAGING_DIR:?STAGING_DIR is not set}"
: "${TARGET_CROSS:?TARGET_CROSS is not set}"
: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is not set}"

TARGET_CC="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}gcc"

if [[ ! -x "$TARGET_CC" ]]; then
    echo "Error: target compiler not found: $TARGET_CC" >&2
    exit 1
fi

echo "=== Target compiler ==="
ls -l "$TARGET_CC"
readlink -f "$TARGET_CC"

echo "=== Target triple ==="
"$TARGET_CC" -dumpmachine

echo "=== Sysroot ==="
"$TARGET_CC" -print-sysroot

echo "=== print-search-dirs ==="
"$TARGET_CC" -print-search-dirs
"$TARGET_CC" -v -E -x c /dev/null

echo "=== Target libraries ==="
for lib in crt1.o crti.o libc.so libgcc_s.so libz.a; do
    printf '%-12s ' "$lib"
    "$TARGET_CC" -print-file-name="$lib"
done

echo "=== Find libz.a ==="
find "$STAGING_DIR" "$TOOLCHAIN_DIR" \
    \( -name 'libz.a' -o -name 'libz.so*' \) -print

echo "=== Build test ==="
cat >/tmp/test.c <<'EOF'
#include <stdio.h>
int main(void) {
    puts("OpenWrt AArch64");
    return 0;
}
EOF

"$TARGET_CC" /tmp/test.c -o /tmp/test-aarch64

file /tmp/test-aarch64
readelf -h /tmp/test-aarch64 | grep -E 'Class:|Machine:'
readelf -l /tmp/test-aarch64 | grep interpreter
