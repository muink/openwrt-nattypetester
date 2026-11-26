# NatTypeTester Console for OpenWrt

This feed packages the upstream [`NatTypeTester.Console`](https://github.com/HMBSbige/NatTypeTester) application as a self-contained .NET Native AOT executable and installs it as:

```text
/usr/bin/nattypetester
```

The package is built from the upstream `10.0.10` source tag by default. It does not install the .NET runtime on the router.

## Supported OpenWrt targets

The release workflow builds the following target/subtarget combinations for both OpenWrt 24.10 and 25.12:

| Architecture | OpenWrt target | .NET RID | Container platform | Package format |
|---|---|---|---|---|
| x86_64 | `x86/64` | `linux-musl-x64` | `linux/amd64` | `.ipk` on 24.10; `.apk` on 25.12 |
| aarch64 | `armsr/armv8` | `linux-musl-arm64` | `linux/arm64` | `.ipk` on 24.10; `.apk` on 25.12 |
| ARMv7 | `armsr/armv7` | `linux-musl-arm` | `linux/arm/v7` | `.ipk` on 24.10; `.apk` on 25.12 |

ARM support is limited to the listed `armsr` targets. In particular, the ARMv7 build targets the `armsr/armv7` profile; it should not be treated as a generic binary for every 32-bit ARM device. ARMv5 and ARMv6 are not supported.

The package Makefile also restricts package selection to the architectures it supports. The SDK's `ARCH_PACKAGES` value determines the actual package output directory; do not infer that directory from the .NET RID.

## How the build works

The package Makefile runs `dotnet publish` inside an architecture-specific Alpine .NET SDK container. The container installs the Native AOT toolchain before publishing:

```sh
apk add --no-cache clang build-base zlib-dev patchelf su-exec
```

The publish uses Native AOT and invariant globalization. The resulting executable is self-contained and does not require a .NET runtime or ICU data on the router.

The NuGet global-packages cache is stored under:

```text
$(DL_DIR)/nattypetester-nuget
```

The container engine defaults to Docker. To use Podman for a local SDK build, pass `CONTAINER_ENGINE=podman` to `make`.

### libc and ABI note

The build currently uses Alpine-based SDK images. The build step adjusts the executable's musl `DT_NEEDED` entry to the libc SONAME used by OpenWrt. This is a SONAME adjustment only; `patchelf` does not convert one musl ABI into another or guarantee that every symbol used by the executable exists on the target system.

Alpine 3.24 uses musl 1.2.6, while the OpenWrt 24.10 and 25.12 SDKs targeted by this workflow use musl 1.2.5. Treat the generated packages as requiring validation on the corresponding OpenWrt release and target. If strict ABI matching is required, the native link step should use the target SDK's musl sysroot rather than relying only on the Alpine container's libc.

Do not use a package built for one OpenWrt release or target on another release/target unless its ABI and dependencies have been verified.

## Build locally with an OpenWrt SDK

Use the SDK matching the OpenWrt release and target/subtarget you want to build for. The SDK must be configured for a musl-based target supported by the package.

Assuming this repository is the feed root and the package directory is `nattypetester-console/`, add the feed to the SDK:

```sh
# Run from the OpenWrt SDK directory.

echo "src-git nattypetester https://github.com/muink/openwrt-nattypetester.git;master" >> feeds.conf
# Or
echo "src-link nattypetester /path/to/nattypetester-feed" >> feeds.conf

./scripts/feeds update nattypetester
./scripts/feeds install -p nattypetester nattypetester-console
make defconfig
```

Build the package:

```sh
make package/feeds/nattypetester/nattypetester-console/download BUILD_LOG=1
make package/feeds/nattypetester/nattypetester-console/compile BUILD_LOG=1 -j$(nproc)
```

To use Podman instead of Docker:

```sh
make package/feeds/nattypetester/nattypetester-console/compile \
    CONTAINER_ENGINE=podman BUILD_LOG=1 -j$(nproc)
```

The Makefile selects the .NET RID, container platform and SDK image from the OpenWrt SDK target architecture. Build each target using its own matching SDK; changing only `ARCH` in an existing SDK is not sufficient.

### Running ARM containers on an x86_64 Linux host

ARM64 and ARMv7 builds run an ARM container. On an x86_64 Linux host, this requires working QEMU user-mode emulation registered with the host kernel through `binfmt_misc`.

The registration must be performed where the host kernel is accessible. A rootless Podman container, a restricted nested container, or a GitHub Actions job container may not have permission to mount `binfmt_misc`. If registration fails with `operation not permitted`, configure it on the outer host, use a runner that already provides the required emulation, or build on a native ARM runner.

For a full Linux host or VM where you have the required privileges, the `tonistiigi/binfmt` image can register the handlers:

```sh
sudo modprobe binfmt_misc
sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true
sudo podman run --privileged --rm \
    docker.io/tonistiigi/binfmt --install arm,arm64
```

This command is not expected to work from every containerized or restricted environment. Verify that the required handlers are registered before attempting an emulated ARM build.

## GitHub Actions builds and releases

The repository's release workflow builds six combinations:

- OpenWrt 24.10: `x86/64`, `armsr/armv8` and `armsr/armv7` (IPK).
- OpenWrt 25.12: `x86/64`, `armsr/armv8` and `armsr/armv7` (APK).

It uses [`fantastic-packages/gh-action-sdk`](https://github.com/fantastic-packages/gh-action-sdk):

- `fantastic-packages/gh-action-sdk@24.10` for OpenWrt 24.10.
- `fantastic-packages/gh-action-sdk@master` for OpenWrt 25.12.

The action receives its SDK selection and feed configuration through environment variables, including `TARGET`, `VERSION`, `FEED_DIR`, `FEEDNAME`, `PACKAGES` and `ARTIFACTS_DIR`. The workflow sets `PACKAGES=nattypetester-console` so that only this package is built.

Both referenced `gh-action-sdk` branches currently include `docker/setup-qemu-action@v4`; no additional QEMU setup step is needed when using those actions. For local builds outside GitHub Actions, follow the QEMU/binfmt instructions above when building ARM containers on x86_64.

The workflow is triggered by:

- Pushing a Git tag.
- Manually dispatching the workflow with an existing tag.

After all six matrix builds succeed, the release job collects the generated packages, creates `SHA256SUMS`, and publishes the `.ipk` and `.apk` files as GitHub Release assets. The OpenWrt SDK version used by each matrix entry is configured in the workflow; update those entries when moving to another point release.

## Source selection and package version

By default, `PKG_UPSTREAM_GITHASH` is empty. The package downloads the upstream `10.0.10` tag archive from GitHub codeload and verifies it with `PKG_HASH`.

To build a specific upstream commit instead, set `PKG_UPSTREAM_GITHASH` to its full commit hash. The Makefile then switches to the Git source download method. After the first download, set `PKG_MIRROR_HASH` to the SHA-256 reported by OpenWrt before publishing the package.

The OpenWrt package version uses `~<short-commit>` when building from a commit. `MinVerVersionOverride` uses a SemVer build-metadata suffix (`+<full-commit>`) for the application's informational version.

## Runtime dependencies and globalization

The package Makefile declares these runtime dependencies:

- `ca-bundle` for certificate authorities used during TLS certificate validation.
- `libopenssl` for OpenSSL-backed TLS/DTLS functionality.
- `zlib` for the native executable's compression support.

The publish command enables `InvariantGlobalization`, so ICU and its language-data packages are not required. Invariant globalization limits culture-sensitive behavior such as locale-specific formatting, collation and casing. This is suitable for the command-line NAT testing use case, but it is not equivalent to full locale-aware .NET behavior.

The final ELF dependencies must still be checked against the actual target SDK and device. Do not add or remove package dependencies solely based on this list; use the generated ELF and runtime tests as the source of truth.

## Install and test

Copy the package matching the device's OpenWrt release and package architecture to the router.

For OpenWrt 24.10 (opkg):

```sh
opkg install ./nattypetester-console_*.ipk
```

For OpenWrt 25.12 (APK), install a signed package using `apk add`. For an intentionally unsigned local build, allow an untrusted package explicitly:

```sh
apk add --allow-untrusted ./nattypetester-console-*.apk
```

Then check the CLI:

```sh
nattypetester --help
```

Run an actual STUN test against a server that supports the requested test method:

```sh
nattypetester rfc5780
```

## Inspect the generated executable

Before publishing a package, inspect the executable produced by the build:

```sh
file NatTypeTester.Console
readelf -h NatTypeTester.Console
readelf -d NatTypeTester.Console | grep NEEDED
scanelf -n NatTypeTester.Console
```

Check that the ELF architecture matches the OpenWrt target and that every required shared library is provided by the target firmware or declared package dependencies. Test the installed package on a device or VM running the exact OpenWrt release and target/subtarget. A successful cross-build alone does not prove runtime compatibility.
