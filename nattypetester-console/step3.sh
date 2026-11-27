
#!/usr/bin/env bash

set -euo pipefail

echo "=== OpenWrt target build environment ==="

: "${TARGET_CROSS:?TARGET_CROSS is not set}"

TOOLCHAIN_DIR=/toolchain
STAGING_DIR=/staging
TARGET_SYSROOT="${TOOLCHAIN_DIR}"

TARGET_CC="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}gcc"
TARGET_CXX="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}g++"
TARGET_AR="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}ar"
TARGET_RANLIB="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}ranlib"
TARGET_STRIP="${TOOLCHAIN_DIR}/bin/${TARGET_CROSS}strip"

export TARGET_CC TARGET_SYSROOT
export LIBRARY_PATH="${STAGING_DIR}/usr/lib:${STAGING_DIR}/lib"

echo "TARGET_CROSS  : ${TARGET_CROSS}"
echo "TARGET_CC     : ${TARGET_CC}"
echo "TARGET_SYSROOT: ${TARGET_SYSROOT}"
echo "STAGING_DIR   : ${STAGING_DIR}"

echo
echo "=== Target compiler ==="

for tool in \
    "${TARGET_CC}" \
    "${TARGET_CXX}" \
    "${TARGET_AR}" \
    "${TARGET_RANLIB}" \
    "${TARGET_STRIP}"; do

    if [[ ! -x "${tool}" ]]; then
        echo "Error: target tool not found or not executable: ${tool}" >&2
        exit 1
    fi

    echo "OK: ${tool}"
done

echo
echo "=== Target triple ==="

"${TARGET_CC}" -dumpmachine

echo
echo "=== Target sysroot ==="

"${TARGET_CC}" --sysroot="${TARGET_SYSROOT}" -print-sysroot

echo
echo "=== Target libraries ==="

for lib in crt1.o crti.o libc.so libgcc_s.so; do
    path="$(
        "${TARGET_CC}" \
            --sysroot="${TARGET_SYSROOT}" \
            -print-file-name="${lib}"
    )"

    if [[ ! -e "${path}" ]]; then
        echo "Error: target library not found: ${lib} (${path})" >&2
        exit 1
    fi

    printf '%-12s %s\n' "${lib}" "${path}"
done

echo
echo "=== OpenWrt staging libraries ==="

for lib in libssl.so libcrypto.so libz.so; do
    path="${STAGING_DIR}/usr/lib/${lib}"

    if [[ ! -e "${path}" ]]; then
        echo "Error: target library not found: ${path}" >&2
        exit 1
    fi

    ls -l "${path}"
done

echo
echo "=== Cross-compile and link test ==="

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cat > "${tmpdir}/test.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    puts("OpenWrt cross-compile test");
    return 0;
}
EOF

"${TARGET_CC}" \
    --sysroot="${TARGET_SYSROOT}" \
    "${tmpdir}/test.c" \
    -o "${tmpdir}/test" \
    -lssl \
    -lcrypto \
    -lz

echo
echo "=== Test ELF ==="

readelf -h "${tmpdir}/test" | grep -E 'Class:|Machine:'

echo
echo "OpenWrt target toolchain check passed."
