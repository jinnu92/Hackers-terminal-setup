#!/usr/bin/env bash
# =============================================================================
#  lib/versions.sh — Pinned versions and SHA-256 digests for direct downloads
#
#  Every binary the installer downloads directly (not through a package
#  manager) is pinned here and verified with hts_download_verify.
#  Naming: <TOOL>_VERSION, and <TOOL>_SHA256_<OS>_<ARCH> for each asset,
#  where OS is DARWIN or LINUX and ARCH is AMD64 or ARM64.
# =============================================================================

# ─── Security tool suites (ad_pivoting, mobile_re, bugbounty, pentest, web_api) ──
# (security-suite pins go below this line)

# Direct downloads (digests verified by hts_download_verify)
# ligolo-ng: digests from upstream ligolo-ng_0.9.2_checksums.txt
LIGOLO_VERSION="0.9.2"
LIGOLO_SHA256_DARWIN_AMD64="94f395296b824d2f9e6aa9791f6afab5ae59d0fda62f874f3a22e0cb572ba9d0"
LIGOLO_SHA256_DARWIN_ARM64="00f2a60e6c9ddfaa5c921e86f270ce33a1447ae52d24b35a352143fb529d3e94"
LIGOLO_SHA256_LINUX_AMD64="6c683c403502d366276595197749e620c975908dae7314c21079ec8ebee4e5d0"
LIGOLO_SHA256_LINUX_ARM64="6430178776bb9efc451a62f6c468fa482c2aded84d10f64f637bfabd0fd8e7ac"
# chisel: digests from upstream chisel_1.12.0_checksums.txt (single binary, gzip)
CHISEL_VERSION="1.12.0"
CHISEL_SHA256_DARWIN_AMD64="4aeae36c867f11c8e8c3f2b913a0e063ea3c6d29e1c14a52ed2e6eef8cfc4395"
CHISEL_SHA256_DARWIN_ARM64="707a4b932eea214765146504a0df246cefc415b4297af65a80dd67cf69ba85a9"
CHISEL_SHA256_LINUX_AMD64="f3f180f1d93aa72cce4e6386f98cc06569a0146fbd65eb4423cf83e6434bcfe6"
CHISEL_SHA256_LINUX_ARM64="2ec6152cd2c74fe0146d4d79e4e7aa174521368c56e433d55e023a92ea404ec3"
# kiterunner: digests from upstream kiterunner_1.0.2_checksums.txt; no darwin arm64 build upstream
KITERUNNER_VERSION="1.0.2"
KITERUNNER_SHA256_DARWIN_AMD64="1aa1844d1c1fcbe5f0ac87e47d30ff4833e430fd456a156d59dbff03f4e3f4dd"
KITERUNNER_SHA256_LINUX_AMD64="6f0b70aabf747de592445a690281897eebbc45927e9264185d34ffb11637613b"
KITERUNNER_SHA256_LINUX_ARM64="ec763297e1a9da49c06fc7853418e5839b03b2326204e7d2dde592f521eddd28"
# jadx: platform-independent zip (needs a JRE); upstream publishes no checksum file, digest computed from the downloaded asset and matching GitHub's release digest
JADX_VERSION="1.5.7"
JADX_SHA256_ZIP="1755e4242ade71a077438723689f404079592ec7764a3a0572f98fef94ebcbf3"
# Caido CLI: digests computed from the downloaded assets; they match the SHA-512 hashes published by api.caido.io/releases/latest
CAIDO_VERSION="0.59.1"
CAIDO_SHA256_DARWIN_AMD64="6dd94ff91b0b2beb83cbb67f94c277381b6f9155f1da90b76a0463990e22624c"
CAIDO_SHA256_DARWIN_ARM64="6809601545a768cd43de203023e1cf253d1d18e6c6d68cd38394809e682e204c"
CAIDO_SHA256_LINUX_AMD64="9d0a9a7b3c0e597fbcd0e4a7ee4eca24c831391abab7997144d5a8ab61ec3ffc"
CAIDO_SHA256_LINUX_ARM64="b71f51940b275993b2d734ade63d24c94cd5f028c8f9e47cda556653541fee15"
# feroxbuster (Linux fallback when no distro package): upstream publishes no checksum file; digests computed from downloaded assets (match GitHub release digests)
FEROXBUSTER_VERSION="2.14.0"
FEROXBUSTER_SHA256_LINUX_AMD64="3ab2cefdb03af090bcf11c4b82bd85a7e8a2b4439237ac06993568eade28ee96"
FEROXBUSTER_SHA256_LINUX_ARM64="8b3c30a2baf249963331ac1f9417e44eeadc00774b127e2452786a4f32a9a7ea"
# BloodHound CE CLI: upstream publishes only .md5 files; sha256 computed from downloaded assets (match GitHub release digests)
BLOODHOUND_CLI_VERSION="0.2.1"
BLOODHOUND_CLI_SHA256_DARWIN_AMD64="2c26e8736a24cbcff97e0e54e4fc6d999203c40b175ba33001f7f35310d5fb5c"
BLOODHOUND_CLI_SHA256_DARWIN_ARM64="6b46ec1bef4b4e05d3c5b631d4afae7346d8a76abd069292aaab9831a9e82cd0"
BLOODHOUND_CLI_SHA256_LINUX_AMD64="2f932d8174f3ed69adf38a8ae94fa58f56d92fadecae8e240f767bb88d449983"
BLOODHOUND_CLI_SHA256_LINUX_ARM64="fd7197939c40fd8dc4b239d2696b610b8aa2f2fc5480bb834ff52e204458a18e"

# Git clones pinned to release tags
RESPONDER_TAG="v3.2.2.0"
SECLISTS_TAG="2026.2"
NIKTO_TAG="2.6.1"
NETEXEC_TAG="v1.5.1"   # NetExec is not on PyPI; installed with pipx/uv from its git tag

# Go tools (go install <path>@v${<TOOL>_VERSION}); versions without the leading v
SUBFINDER_VERSION="2.17.0"
HTTPX_VERSION="1.12.0"
NUCLEI_VERSION="3.11.1"
KATANA_VERSION="1.8.0"
DNSX_VERSION="1.3.1"
INTERACTSH_VERSION="1.4.1"
GAU_VERSION="2.2.4"
HAKRAWLER_VERSION="0.0.0-20260805040537-52a16fe61bd1"   # no release tags upstream; pseudo-version of HEAD
WAYBACKURLS_VERSION="0.1.0"
AMASS_VERSION="5.1.3"
DALFOX_VERSION="2.13.0"                                 # last Go release (dalfox 3.x is a Rust rewrite)
FFUF_VERSION="2.3.0"
GOBUSTER_VERSION="3.8.2"

# ─── end security tool suites ─────────────────────────────────────────────────




# ─── Platform, workflow and cloud (workflow, dev, cloud, cloud_devsec, fonts) ──
# (platform pins go below this line)

# Aqua / Anchore installers: the script URL is pinned to the same tag and the
# version is also passed to the installer's own version argument.
TRIVY_VERSION="v0.76.2"
SYFT_VERSION="v1.57.2"
GRYPE_VERSION="v0.122.1"

# yq (mikefarah) — single binary
YQ_VERSION="v4.54.3"
YQ_SHA256_LINUX_AMD64="129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973"
YQ_SHA256_LINUX_ARM64="89f69310b61b68d1245065a1241d1fc843f7a36cd6103ffd77ad987613bd1b67"

# lazygit — release tarball (asset names use the version without the "v")
LAZYGIT_VERSION="0.66.3"
LAZYGIT_SHA256_LINUX_AMD64="0a23f429a95f0d09db298b3c291536d818de066aa5a85c255806f0490ff6656b"
LAZYGIT_SHA256_LINUX_ARM64="ac0b48237f3d0283813e7154ec063237e519532feb0470c0881a1793ee78fd42"

# xh — musl release tarball (its own installer script floats to "latest" and prompts)
XH_VERSION="v0.26.3"
XH_SHA256_LINUX_AMD64="cbbf53bd76007d57d95e4bed8ba7fb3b7fcec22af4bdfc1ff119cd5de351e74f"
XH_SHA256_LINUX_ARM64="a45d8cb6c234c6850f9fc2395fc3544ab7691fb511237f00179aedba1bcd525e"

# kubescape — single binary
KUBESCAPE_VERSION="v4.0.21"
KUBESCAPE_SHA256_LINUX_AMD64="7a997a0d46ea37f83fa33d318e615721f569f3721b36a96f7f2c0254b6570fae"
KUBESCAPE_SHA256_LINUX_ARM64="7a4c963e3b173380dca2788c0a24144cc8a793e731edc28b902bf26a3d98c649"

# kube-bench — release tarball (binary + cfg/), asset names use no "v"
KUBE_BENCH_VERSION="0.16.0"
KUBE_BENCH_SHA256_LINUX_AMD64="82dbc7e598740dc9344d41f8ad0b8210d57c4c00bdb2c5f1d8a69a2b98baddcf"
KUBE_BENCH_SHA256_LINUX_ARM64="64500561f5fcaa3f86fe951ed26bbfc28f7bbf3d2eac13843abfd2924955d10b"

# osv-scanner — single binary
OSV_SCANNER_VERSION="v2.7.1"
OSV_SCANNER_SHA256_LINUX_AMD64="fb7dab19a8bd9bbe5c3189f09d4b7ee1820c9553a23bac202648a56efd2f6ee8"
OSV_SCANNER_SHA256_LINUX_ARM64="983d22fbad9724514e3fcc6acc83b5fa64c5ffa6b0d9f510028f22c1b223ff81"

# Nerd Fonts release archives (.tar.xz)
NERDFONTS_VERSION="v3.5.1"
NERDFONTS_SHA256_JETBRAINSMONO="04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
NERDFONTS_SHA256_FIRACODE="68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207"
NERDFONTS_SHA256_HACK="cdd389472e10e2261520140ff1b382b4f8a226af5fd0b2735b975d31151d9c3c"
NERDFONTS_SHA256_CASCADIACODE="ae598e9401e2846aa3ee364513715de0490b844a4b54f0768991f45f23aa8369"


# MesloLGS NF (Powerlevel10k fonts) — pinned to a commit of powerlevel10k-media
MESLO_MEDIA_COMMIT="145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d"
MESLO_SHA256_REGULAR="d97946186e97f8d7c0139e8983abf40a1d2d086924f2c5dbf1c29bd8f2c6e57d"
MESLO_SHA256_BOLD="b6c0199cf7c7483c8343ea020658925e6de0aeb318b89908152fcb4d19226003"
MESLO_SHA256_ITALIC="6f357bcbe2597704e157a915625928bca38364a89c22a4ac36e7a116dcd392ef"
MESLO_SHA256_BOLD_ITALIC="56b4131adecec052c4b324efb818dd326d586dbc316fc68f98f1cae2eb8d1220"


# ─── end platform, workflow and cloud ─────────────────────────────────────────




# ─── Language runtimes ────────────────────────────────────────────────────────
# Go — official toolchain from go.dev, digests from https://go.dev/dl/?mode=json
GO_VERSION="1.27.4"
GO_SHA256_LINUX_AMD64="7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840"
GO_SHA256_LINUX_ARM64="3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92"
GO_SHA256_DARWIN_AMD64="2b799377704ef12db39bd254995d5c348c9cc8d86562ca817724390e56c38f43"
GO_SHA256_DARWIN_ARM64="91a44a2b8a716600ad94a4f143e156116620db8828086a6e3602291be9bd0bb4"

# Node.js — the installer always installs the newest LTS line; this is the
# oldest line it leaves in place (the oldest LTS still receiving fixes).
NODE_MIN_MAJOR=22
# ─── end language runtimes ────────────────────────────────────────────────────
