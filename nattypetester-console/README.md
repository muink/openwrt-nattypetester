# NatTypeTester Console for OpenWrt x86_64

This package builds the upstream `10.0.10` Console project as a Native AOT
`linux-musl-x64` executable and installs it as `/usr/bin/nattypetester`.

## Build requirements

- OpenWrt x86_64 SDK (musl target)
- Docker or Podman on the SDK host
- Network access from the container for Alpine packages and NuGet restore

The SDK host is normally glibc-based. Native AOT does not support direct
cross-OS compilation from glibc to musl, so the build runs inside Microsoft's
.NET 10 Alpine SDK image. `CONTAINER_ENGINE=podman` can be passed to make when
using Podman.

## Feed setup

Place this directory in a feed, update/install the feed, and download sources:

```sh
make package/feeds/<feed>/nattypetester-console/download V=s
```

The source commit is pinned. The first download/check run will report the
reproducible `PKG_MIRROR_HASH`; copy that SHA-256 into the Makefile before
committing or publishing the package.

Build:

```sh
make package/feeds/<feed>/nattypetester-console/compile V=s
```

Install on the router:

```sh
opkg install nattypetester-console_*.ipk
nattypetester --help
```

The package's runtime dependencies should be verified against the generated
ELF with `scanelf -n` / `ldd` and an actual OpenWrt x86_64 test run. In
particular, this first version declares the OpenWrt ICU, OpenSSL, CA bundle,
zlib, and zoneinfo packages for non-invariant globalization and TLS support.
