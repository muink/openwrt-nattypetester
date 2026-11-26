# NatTypeTester Console for OpenWrt

This feed package builds the upstream `NatTypeTester.Console` project as a
Native AOT executable and installs it as `/usr/bin/nattypetester`.

## Supported targets

| OpenWrt Architecture | OpenWrt Config | .NET RID | Container Platform |
|---|---|---|---|
| x86_64 | `x86_64` | `linux-musl-x64` | `linux/amd64` |
| aarch64 | `aarch64` | `linux-musl-arm64` | `linux/arm64/v8` |
| ARMv7 | `arm_v7` | `linux-musl-arm` | `linux/arm/v7` |

ARMv7 support is limited to 32-bit ARMv7 targets. ARMv5 and ARMv6 are not supported.

The package is restricted to the supported architectures through OpenWrt's package dependency conditions.

## Build Prerequisites

- OpenWrt SDK for the target architecture.
- Docker or Podman.
- Internet access for downloading the .NET SDK image and NuGet packages.

Native AOT builds are performed inside an Alpine-based .NET SDK container to avoid host/target libc incompatibilities.

When building ARM targets on an x86_64 host, QEMU and binfmt support are required to run ARM containers.

The container installs the Native AOT toolchain before publishing:

```sh
apk add --no-cache clang build-base zlib-dev patchelf
```

The NuGet global-packages directory is cached under `$(DL_DIR)/nattypetester-nuget`
between builds.

## Building for x86_64

Use an OpenWrt SDK whose target architecture is `x86_64`. Docker or Podman can
run the matching `linux/amd64` .NET SDK image natively on an x86_64 host:

```sh
make package/feeds/<feed>/nattypetester-console/download V=s
make package/feeds/<feed>/nattypetester-console/compile V=s
```

## Building for aarch64

Use an OpenWrt SDK for the desired aarch64 target/subtarget (for example, the
SDK corresponding to the device's target family). The Makefile selects
`linux-musl-arm64` and `linux/arm64` automatically when that SDK reports
`ARCH=aarch64`.

### On an ARM build host

No CPU emulation is needed. Docker or Podman runs the ARM .NET SDK image
natively. Run the same feed download and compile commands shown above.

### On an x86_64 Linux build host

The SDK itself can still run on the x86_64 host, but the build container must
run as ARM. Docker Engine needs ARM `binfmt_misc`/QEMU user-mode emulation
registered on the host. One way to register it is:

```sh
sudo modprobe binfmt_misc

sudo mount -t binfmt_misc \
    binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true

sudo podman run --privileged --rm \
    docker.io/tonistiigi/binfmt --install arm,arm64
```

Verify ARM container support:

```sh
# aarch64
podman run --rm \
	--platform linux/arm64 \
	--entrypoint sh \
	mcr.microsoft.com/dotnet/sdk:10.0.404-alpine3.24 \
	-c 'uname -m && dotnet --version'

# ARMv7
podman run --rm \
	--platform linux/arm/v7 \
	--entrypoint sh \
	mcr.microsoft.com/dotnet/sdk:10.0.404-alpine3.24-arm32v7 \
	-c 'uname -m && dotnet --version'
```

It should print `aarch64`. Then use the aarch64 OpenWrt SDK and run:

```sh
make package/feeds/<feed>/nattypetester-console/download BUILD_LOG=1
make package/feeds/<feed>/nattypetester-console/compile BUILD_LOG=1 -j$(nproc)
```

`--platform linux/arm64` selects the ARM64 image; it does not install or
configure CPU emulation by itself. On Docker Desktop, multi-architecture
emulation is generally provided by the desktop VM. For Podman on Linux, ensure
that the host has a working ARM64 QEMU/binfmt handler before building an ARM64
container on an x86_64 host.

### ARMv7 (32-bit ARM)

ARMv7 builds use the `linux-musl-arm` RID and an ARMv7 container.

On x86_64 hosts, QEMU/binfmt must be configured before building.

Make sure the OpenWrt SDK is configured for an ARMv7 target (`CONFIG_arm_v7=y`).

Build the package using the normal OpenWrt SDK commands:

```bash
make package/feeds/<feed>/nattypetester-console/compile BUILD_LOG=1 -j$(nproc)
```

The Makefile automatically selects:

- .NET RID: linux-musl-arm
- Container platform: linux/arm/v7
- Native AOT compiler: ARM32

ARMv7 builds have not been validated on all OpenWrt subtargets.

Verify the resulting binary and its runtime dependencies on the target device.

## Source selection

By default, `PKG_UPSTREAM_GITHASH` is empty and the package downloads the
upstream `10.0.10` tag archive from GitHub codeload. `PKG_HASH` verifies that
source archive.

To build a specific commit instead, set `PKG_UPSTREAM_GITHASH` to its full Git
commit hash. The Makefile switches to the Git download method and uses
`PKG_MIRROR_HASH` for the generated source archive. After the first download,
use the SHA-256 reported by OpenWrt to fill in `PKG_MIRROR_HASH` before
publishing the package.

The package version uses OpenWrt's `~` commit suffix, while
`MinVerVersionOverride` uses SemVer build metadata (`+<commit>`) for the
application's informational version.

## Runtime Verification

After building, inspect the generated ELF dependencies:

```bash
readelf -d NatTypeTester.Console | grep NEEDED
```

The build process patches Alpine's musl SONAME to match OpenWrt's libc.so.

Check all remaining shared library dependencies against the target OpenWrt system.

For ARMv7, pay particular attention to possible libatomic dependencies.
If libatomic.so.1 is required, add +libatomic to the package dependencies.

Finally, test the executable on the target device:

```bash
nattypetester --help
nattypetester rfc5780
```

## Runtime dependencies and globalization

The package declares these runtime dependencies:

- `ca-bundle` for TLS certificate validation.
- `libopenssl` for OpenSSL-backed TLS/DTLS functionality.
- `zlib` for compression support used by the Native AOT executable/runtime.

The publish command sets `InvariantGlobalization=true`, so ICU and its language
data packages are not required. Invariant globalization reduces globalization
functionality (for example, culture-specific formatting, collation and
casing); this is suitable for the command-line NAT testing use case, but it
is not equivalent to full locale-aware .NET behavior.

## Install and test

Install the generated package on a matching OpenWrt device. OpenWrt releases
using APK can install the `.apk` package with:

```sh
apk add ./nattypetester-console-*.apk
```

Older releases using opkg can install the `.ipk` package with:

```sh
opkg install ./nattypetester-console_*.ipk
```

Then run:

```sh
nattypetester --help
```

Before publishing a new build, inspect the executable's architecture and
shared-library dependencies. For example, from the build host:

```sh
file <path-to-NatTypeTester.Console>
readelf -h <path-to-NatTypeTester.Console>
scanelf -n <path-to-NatTypeTester.Console>
```

Also test the package on an actual router of each target architecture. The
Makefile and this guide describe the intended build flow; they do not replace
runtime verification against the exact OpenWrt release and device image.
