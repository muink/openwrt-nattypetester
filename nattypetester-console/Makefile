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

# NativeAOT is built in an Alpine container because the OpenWrt SDK host is
# glibc-based while the target is musl. NativeAOT does not support cross-OS
# compilation directly.
CONTAINER_ENGINE?=docker
DOTNET_IMAGE?=mcr.microsoft.com/dotnet/sdk:10.0.404-alpine3.24
NUGET_CACHE_DIR:=$(DL_DIR)/nattypetester-nuget

ifeq ($(ARCH),x86_64)
  DOTNET_RID:=linux-musl-x64
  CONTAINER_PLATFORM:=linux/amd64
else ifeq ($(ARCH),aarch64)
  DOTNET_RID:=linux-musl-arm64
  CONTAINER_PLATFORM:=linux/arm64
else ifeq ($(ARCH),arm)
  ifeq ($(CONFIG_arm_v7),y)
    DOTNET_RID:=linux-musl-arm
    CONTAINER_PLATFORM:=linux/arm/v7
    DOTNET_IMAGE?=mcr.microsoft.com/dotnet/sdk:10.0.404-alpine3.24-arm32v7
  endif
endif

include $(INCLUDE_DIR)/package.mk

define Package/nattypetester-console
  SECTION:=net
  CATEGORY:=Network
  TITLE:=NatTypeTester STUN console client
  URL:=https://github.com/HMBSbige/NatTypeTester
  DEPENDS:=@(aarch64||x86_64||arm_v7) +ca-bundle +libopenssl +zlib
endef

define Package/nattypetester-console/description
  Console application for testing NAT behavior through STUN (RFC 3489 / RFC 5780).
endef

define Build/Compile
	@env \
		ARCH="$(ARCH)" \
		TARGET_CROSS="$(TARGET_CROSS)" \
		TARGET_CC="$(TARGET_CC)" \
		STAGING_DIR="$(STAGING_DIR)" \
		TOOLCHAIN_DIR="$(TOOLCHAIN_DIR)" \
		bash "$(CURDIR)/step3.sh"
	@exit 1
	@test -n "$(DOTNET_RID)" || { \
		echo "Error: unsupported target architecture: $(ARCH)" >&2; \
		exit 1; \
	}
	@command -v $(CONTAINER_ENGINE) >/dev/null 2>&1 || { \
		echo "Error: $(CONTAINER_ENGINE) is required." >&2; \
		exit 1; \
	}
	@mkdir -p $(NUGET_CACHE_DIR)
	$(CONTAINER_ENGINE) run --rm \
		--platform $(CONTAINER_PLATFORM) \
		--network host \
		-e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
		-e DOTNET_NOLOGO=1 \
		-e NUGET_PACKAGES=/nuget \
		-e BUILD_UID=$(shell id -u) \
		-e BUILD_GID=$(shell id -g) \
		-e HOME=/tmp \
		-e DOTNET_CLI_HOME=/tmp/dotnet-cli \
		-e XDG_RUNTIME_DIR=/tmp/dotnet-runtime \
		-e ARCH="$(ARCH)" \
		-e TARGET_CROSS="$(TARGET_CROSS)" \
		-e TARGET_CC="$(TARGET_CC)" \
		-e STAGING_DIR="$(STAGING_DIR)" \
		-e TOOLCHAIN_DIR="$(TOOLCHAIN_DIR)" \
		-v "$(PKG_BUILD_DIR):/src" \
		-v "$(NUGET_CACHE_DIR):/nuget" \
		-w /src \
		$(DOTNET_IMAGE) \
		sh -euxc 'apk add --no-cache clang build-base zlib-dev patchelf su-exec; \
			mkdir -p /tmp/dotnet-runtime /tmp/dotnet-cli; \
			chown "$$$$BUILD_UID:$$$$BUILD_GID" \
				"$$$$DOTNET_CLI_HOME" "$$$$XDG_RUNTIME_DIR"; \
			chmod 700 "$$$$XDG_RUNTIME_DIR"; \
			su-exec "$$$$BUILD_UID:$$$$BUILD_GID" dotnet publish \
				src/NatTypeTester.Console/NatTypeTester.Console.csproj \
				-c Release \
				-r $(DOTNET_RID) \
				--self-contained true \
				-p:PublishAot=true \
				-p:InvariantGlobalization=true \
				-p:MinVerVersionOverride=$(PKG_MINVER_VERSION) \
				-o /src/publish; \
			app=/src/publish/NatTypeTester.Console; \
			echo "Checking NativeAOT output..."; \
			ls -lh "$$$$app"; \
			test -x "$$$$app"; \
			echo "ELF DT_NEEDED:"; \
			needed=$$$$(patchelf --print-needed "$$$$app"); \
			printf "%s\n" "$$$$needed"; \
			musl_libc=$$$$(printf "%s\n" "$$$$needed" | \
				sed -n "/^libc[.]musl-.*[.]so[.]1$$$$/p"); \
			if [ -n "$$$$musl_libc" ]; then \
				echo "Replacing $$$$musl_libc with libc.so"; \
				patchelf --replace-needed "$$$$musl_libc" libc.so "$$$$app"; \
			elif printf "%s\n" "$$$$needed" | grep -qx "libc.so"; then \
				echo "Already using libc.so"; \
			else \
				echo "Error: unexpected libc dependency" >&2; \
				exit 1; \
			fi; \
			echo "Final ELF DT_NEEDED:"; \
			patchelf --print-needed "$$$$app"'
endef

define Package/nattypetester-console/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/publish/NatTypeTester.Console $(1)/usr/bin/nattypetester
endef

$(eval $(call BuildPackage,nattypetester-console))
