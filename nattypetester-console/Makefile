
# SPDX-License-Identifier: LGPL-3.0
#
# Copyright (C) 2026 Anya Lin <hukk1996@gmail.com>

include $(TOPDIR)/rules.mk

PKG_UPSTREAM_NAME:=NatTypeTester
PKG_UPSTREAM_VERSION:=10.0.10
PKG_UPSTREAM_GITHASH:=

PKG_NAME:=nattypetester-console
PKG_VERSION:=$(PKG_UPSTREAM_VERSION)$(if $(PKG_UPSTREAM_GITHASH),~$(call version_abbrev,$(PKG_UPSTREAM_GITHASH)))
PKG_RELEASE:=1
PKG_SOURCE_SUBDIR:=$(PKG_UPSTREAM_NAME)-$(PKG_UPSTREAM_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

ifeq ($(PKG_UPSTREAM_GITHASH),)
  PKG_SOURCE_URL:=https://codeload.github.com/HMBSbige/NatTypeTester/tar.gz/refs/tags
  PKG_SOURCE_URL_FILE:=$(PKG_VERSION)
  PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.gz
  PKG_HASH:=428479cdc7500753282f73fd2be182cf48d71882dedcf0b090f41b2084842822
else
  PKG_SOURCE_PROTO:=git
  PKG_SOURCE_URL:=https://github.com/HMBSbige/NatTypeTester.git
  PKG_SOURCE_VERSION:=$(PKG_UPSTREAM_GITHASH)
  PKG_SOURCE:=$(PKG_SOURCE_SUBDIR)-$(PKG_SOURCE_VERSION).tar.gz
  PKG_MIRROR_HASH:=
endif

PKG_MAINTAINER:=Anya Lin <hukk1996@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MINVER_VERSION:=$(PKG_UPSTREAM_VERSION)$(if $(PKG_UPSTREAM_GITHASH),+$(PKG_UPSTREAM_GITHASH))

# Use a native x86_64 Linux container for both target architectures.
# This avoids running the ARM64 .NET SDK / ILC through QEMU.
CONTAINER_ENGINE?=docker
CONTAINER_PLATFORM:=linux/amd64
DOTNET_IMAGE?=mcr.microsoft.com/dotnet/sdk:10.0.404

NUGET_CACHE_DIR:=$(DL_DIR)/nattypetester-nuget

ifeq ($(ARCH),x86_64)
  DOTNET_RID:=linux-musl-x64
else ifeq ($(ARCH),aarch64)
  DOTNET_RID:=linux-musl-arm64
endif

include $(INCLUDE_DIR)/package.mk

define Package/nattypetester-console
  SECTION:=net
  CATEGORY:=Network
  TITLE:=NatTypeTester STUN console client
  URL:=https://github.com/HMBSbige/NatTypeTester
  DEPENDS:=@(aarch64||x86_64) +ca-bundle +libopenssl +zlib
endef

define Package/nattypetester-console/description
  Console application for testing NAT behavior through STUN (RFC 3489 / RFC 5780).
endef

define Build/Compile
	@test -n "$(DOTNET_RID)" || { \
		echo "Error: unsupported target architecture: $(ARCH)" >&2; \
		exit 1; \
	}
	@test -n "$(TARGET_CROSS)" || { \
		echo "Error: TARGET_CROSS is not set." >&2; \
		exit 1; \
	}
	@command -v $(CONTAINER_ENGINE) >/dev/null 2>&1 || { \
		echo "Error: $(CONTAINER_ENGINE) is required." >&2; \
		exit 1; \
	}
	@test -d "$(TOOLCHAIN_DIR)" || { \
		echo "Error: TOOLCHAIN_DIR not found: $(TOOLCHAIN_DIR)" >&2; \
		exit 1; \
	}
	@test -d "$(STAGING_DIR)" || { \
		echo "Error: STAGING_DIR not found: $(STAGING_DIR)" >&2; \
		exit 1; \
	}
	@mkdir -p "$(NUGET_CACHE_DIR)"
	$(CONTAINER_ENGINE) run --rm \
		--platform $(CONTAINER_PLATFORM) \
		--network host \
		-e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
		-e DOTNET_NOLOGO=1 \
		-e NUGET_PACKAGES=/nuget \
		-e DOTNET_CLI_HOME=/tmp/dotnet-cli \
		-e HOME=/tmp \
		-e XDG_RUNTIME_DIR=/tmp/dotnet-runtime \
		-e TARGET_CROSS="$(TARGET_CROSS)" \
		-e TARGET_RID="$(DOTNET_RID)" \
		-e BUILD_UID=$(shell id -u) \
		-e BUILD_GID=$(shell id -g) \
		-v "$(PKG_BUILD_DIR):/src" \
		-v "$(CURDIR):/build:ro" \
		-v "$(TOOLCHAIN_DIR):/toolchain:ro" \
		-v "$(STAGING_DIR):/staging:ro" \
		-v "$(NUGET_CACHE_DIR):/nuget" \
		-w /src \
		$(DOTNET_IMAGE) \
		sh -euxc ' \
			apt-get update; \
			apt-get install -y --no-install-recommends \
				binutils util-linux; \
			rm -rf /var/lib/apt/lists/*; \
			mkdir -p "$$$$DOTNET_CLI_HOME" "$$$$XDG_RUNTIME_DIR"; \
			chown "$$$$BUILD_UID:$$$$BUILD_GID" \
				"$$$$DOTNET_CLI_HOME" "$$$$XDG_RUNTIME_DIR"; \
			chmod 700 "$$$$XDG_RUNTIME_DIR"; \
			echo "=== Build environment ==="; \
			uname -m; \
			dotnet --info; \
			echo "=== OpenWrt toolchain check ==="; \
			bash /build/step3.sh; \
			echo "=== NativeAOT publish ==="; \
			TARGET_CC="/toolchain/bin/$${TARGET_CROSS}gcc"; \
			TARGET_AR="/toolchain/bin/$${TARGET_CROSS}ar"; \
			TARGET_SYSROOT=/toolchain; \
			LIBRARY_PATH="/staging/usr/lib:/staging/lib"; \
			export TARGET_CC TARGET_AR TARGET_SYSROOT LIBRARY_PATH; \
			setpriv \
				--reuid="$$$$BUILD_UID" \
				--regid="$$$$BUILD_GID" \
				--clear-groups \
				env \
					HOME=/tmp \
					DOTNET_CLI_HOME="$$$$DOTNET_CLI_HOME" \
					XDG_RUNTIME_DIR="$$$$XDG_RUNTIME_DIR" \
					NUGET_PACKAGES=/nuget \
					LIBRARY_PATH="$$$$LIBRARY_PATH" \
					TARGET_CC="$$$$TARGET_CC" \
					TARGET_SYSROOT="$$$$TARGET_SYSROOT" \
				dotnet publish \
					src/NatTypeTester.Console/NatTypeTester.Console.csproj \
					-c Release \
					-r $(DOTNET_RID) \
					--self-contained true \
					-p:PublishAot=true \
					-p:InvariantGlobalization=true \
					-p:MinVerVersionOverride=$(PKG_MINVER_VERSION) \
					-p:CppCompilerAndLinker=/build/cross-linker.sh \
					-p:CppLibCreator="$$$$TARGET_AR" \
					-p:SysRoot=/toolchain \
					-p:UseSystemZlib=true \
					-p:StripSymbols=false \
					-v:diag \
					-bl:/src/nativeaot.binlog \
					-o /src/publish; \
			echo "=== Checking NativeAOT output ==="; \
			app=/src/publish/NatTypeTester.Console; \
			test -s "$$$$app"; \
			echo "=== ELF header ==="; \
			readelf -h "$$$$app" | grep -E "Class:|Machine:"; \
			echo "=== ELF interpreter ==="; \
			readelf -l "$$$$app" | grep -i interpreter || true; \
			echo "=== ELF DT_NEEDED ==="; \
			readelf -d "$$$$app" | grep NEEDED || true; \
			echo "=== Stripping symbols ==="; \
			"/toolchain/bin/$${TARGET_CROSS}strip" \
				--strip-unneeded "$$$$app"; \
			chmod 755 "$$$$app"; \
			ls -lh "$$$$app"; \
		'
endef

define Package/nattypetester-console/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/publish/NatTypeTester.Console $(1)/usr/bin/nattypetester
endef

$(eval $(call BuildPackage,nattypetester-console))
