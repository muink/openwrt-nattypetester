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
	@command -v $(CONTAINER_ENGINE) >/dev/null 2>&1 || { \
		echo "Error: $(CONTAINER_ENGINE) is required to build NatTypeTester NativeAOT." >&2; \
		exit 1; \
	}
	@mkdir -p $(NUGET_CACHE_DIR)
	$(CONTAINER_ENGINE) run --rm \
		--platform $(CONTAINER_PLATFORM) \
		--network host \
		-e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
		-e DOTNET_NOLOGO=1 \
		-e NUGET_PACKAGES=/nuget \
		-v "$(PKG_BUILD_DIR):/src" \
		-v "$(NUGET_CACHE_DIR):/nuget" \
		-w /src \
		$(DOTNET_IMAGE) \
		sh -ec 'apk add --no-cache clang build-base zlib-dev patchelf; \
			dotnet publish src/NatTypeTester.Console/NatTypeTester.Console.csproj \
				-c Release \
				-r $(DOTNET_RID) \
				--self-contained true \
				-p:PublishAot=true \
				-p:InvariantGlobalization=true \
				-p:MinVerVersionOverride=$(PKG_MINVER_VERSION) \
				-o /src/publish; \
			app=/src/publish/NatTypeTester.Console; \
			test -x "$$app"; \
			needed=$$(patchelf --print-needed "$$app"); \
			echo "ELF DT_NEEDED:"; \
			echo "$$needed"; \
			musl_libc=$$(printf '%s\n' "$$needed" | \
				grep -E '^libc\.musl-.*\.so\.1$$' || true); \
			if [ -n "$$musl_libc" ]; then \
				echo "Replacing $$musl_libc with libc.so"; \
				patchelf --replace-needed "$$musl_libc" libc.so "$$app"; \
			elif printf '%s\n' "$$needed" | grep -qx 'libc.so'; then \
				echo "Already using OpenWrt libc.so"; \
			else \
				echo "Error: unexpected libc dependency" >&2; \
				exit 1; \
			fi; \
			echo "ELF DT_NEEDED after patch:"; \
			patchelf --print-needed "$$app"'

endef

define Package/nattypetester-console/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/publish/NatTypeTester.Console $(1)/usr/bin/nattypetester
endef

$(eval $(call BuildPackage,nattypetester-console))
