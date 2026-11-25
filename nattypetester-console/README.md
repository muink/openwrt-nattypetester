# NatTypeTester Console for OpenWrt

This feed package builds the upstream `NatTypeTester.Console` project as a
Native AOT executable and installs it as `/usr/bin/nattypetester`.

## Supported targets

| OpenWrt target architecture (`ARCH`) | .NET RID | Container platform |
| --- | --- | --- |
| `x86_64` | `linux-musl-x64` | `linux/amd64` |
| `aarch64` | `linux-musl-arm64` | `linux/arm64` |

The package Makefile selects the RID and container platform from the OpenWrt
SDK's `ARCH` variable. `ARCH` describes the SDK **target**, not the CPU
architecture of the build host. Use an SDK built for the device's actual
OpenWrt target/subtarget.

## Build requirements

- An OpenWrt SDK for the desired target (x86_64 or aarch64).
- Docker or Podman on the SDK build host.
- Network access from the container to Alpine package repositories and NuGet.

The OpenWrt SDK host is normally glibc-based, while OpenWrt targets use musl.
The package therefore runs `dotnet publish` inside the official .NET 10 Alpine
SDK image, with the container platform matching the target architecture. The
host does not need a .NET SDK installed.

The container installs the Native AOT toolchain before publishing:

```sh
apk add --no-cache clang build-base zlib-dev
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

### On an ARM64 build host

No CPU emulation is needed. Docker or Podman runs the ARM64 .NET SDK image
natively. Run the same feed download and compile commands shown above.

### On an x86_64 Linux build host

The SDK itself can still run on the x86_64 host, but the build container must
run as ARM64. Docker Engine needs ARM64 `binfmt_misc`/QEMU user-mode emulation
registered on the host. One way to register it is:

```sh
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

Check that the ARM64 container can start before building:

```sh
docker run --rm --platform linux/arm64 alpine:latest uname -m
```

It should print `aarch64`. Then use the aarch64 OpenWrt SDK and run:

```sh
make package/feeds/<feed>/nattypetester-console/download V=s
make package/feeds/<feed>/nattypetester-console/compile V=s
```

`--platform linux/arm64` selects the ARM64 image; it does not install or
configure CPU emulation by itself. On Docker Desktop, multi-architecture
emulation is generally provided by the desktop VM. For Podman on Linux, ensure
that the host has a working ARM64 QEMU/binfmt handler before building an ARM64
container on an x86_64 host.

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
