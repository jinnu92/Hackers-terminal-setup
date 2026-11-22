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



# ─── end platform, workflow and cloud ─────────────────────────────────────────
