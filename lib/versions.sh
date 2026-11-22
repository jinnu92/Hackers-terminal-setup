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
