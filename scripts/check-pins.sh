#!/usr/bin/env bash
# =============================================================================
#  scripts/check-pins.sh — compare pinned versions with the latest upstream
#
#  Reads the *_VERSION / *_TAG pins in lib/versions.sh and the MCP_*_VERSION
#  pins in lib/ai_mcp.sh, looks up the latest upstream release for each and
#  prints a Markdown table of current vs latest.
#
#  Exit status: 0 = all pins current (lookup failures are reported but do not
#               fail), 1 = at least one pin is behind, 3 = usage/tool error.
#  Env:   GH_TOKEN / GITHUB_TOKEN  used by gh or curl for GitHub API lookups
#         PINS_REPORT              also write the table to this file
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=("$ROOT/lib/versions.sh" "$ROOT/lib/ai_mcp.sh")

command -v jq >/dev/null 2>&1 || { echo "check-pins: jq is required" >&2; exit 3; }
command -v curl >/dev/null 2>&1 || { echo "check-pins: curl is required" >&2; exit 3; }

# ─── Mapping: variable name -> upstream source ───────────────────────────────
#   gh:<owner>/<repo>[:<max-major>]   latest GitHub release (or tag if no releases)
#   npm:<package>                     npm registry "latest" dist-tag
#   pypi:<package>                    PyPI latest
#   godev                             go.dev latest stable Go release
#   skip:<reason>                     not checkable (pseudo-version, commit pin...)
source_for() {
  case "$1" in
    LIGOLO_VERSION)          echo "gh:nicocha30/ligolo-ng" ;;
    CHISEL_VERSION)          echo "gh:jpillora/chisel" ;;
    KITERUNNER_VERSION)      echo "gh:assetnote/kiterunner" ;;
    JADX_VERSION)            echo "gh:skylot/jadx" ;;
    CAIDO_VERSION)           echo "gh:caido/caido" ;;
    FEROXBUSTER_VERSION)     echo "gh:epi052/feroxbuster" ;;
    BLOODHOUND_CLI_VERSION)  echo "gh:SpecterOps/bloodhound-cli" ;;
    RESPONDER_TAG)           echo "gh:lgandx/Responder" ;;
    SECLISTS_TAG)            echo "gh:danielmiessler/SecLists" ;;
    NIKTO_TAG)               echo "gh:sullo/nikto" ;;
    NETEXEC_TAG)             echo "gh:Pennyw0rth/NetExec" ;;
    SUBFINDER_VERSION)       echo "gh:projectdiscovery/subfinder" ;;
    HTTPX_VERSION)           echo "gh:projectdiscovery/httpx" ;;
    NUCLEI_VERSION)          echo "gh:projectdiscovery/nuclei" ;;
    KATANA_VERSION)          echo "gh:projectdiscovery/katana" ;;
    DNSX_VERSION)            echo "gh:projectdiscovery/dnsx" ;;
    INTERACTSH_VERSION)      echo "gh:projectdiscovery/interactsh" ;;
    GAU_VERSION)             echo "gh:lc/gau" ;;
    HAKRAWLER_VERSION)       echo "skip:pseudo-version of HEAD (no release tags upstream)" ;;
    WAYBACKURLS_VERSION)     echo "gh:tomnomnom/waybackurls" ;;
    AMASS_VERSION)           echo "gh:owasp-amass/amass" ;;
    DALFOX_VERSION)          echo "gh:hahwul/dalfox:2" ;;   # 3.x is a Rust rewrite, no go install
    FFUF_VERSION)            echo "gh:ffuf/ffuf" ;;
    GOBUSTER_VERSION)        echo "gh:OJ/gobuster" ;;
    TRIVY_VERSION)           echo "gh:aquasecurity/trivy" ;;
    SYFT_VERSION)            echo "gh:anchore/syft" ;;
    GRYPE_VERSION)           echo "gh:anchore/grype" ;;
    YQ_VERSION)              echo "gh:mikefarah/yq" ;;
    LAZYGIT_VERSION)         echo "gh:jesseduffield/lazygit" ;;
    XH_VERSION)              echo "gh:ducaale/xh" ;;
    KUBESCAPE_VERSION)       echo "gh:kubescape/kubescape" ;;
    KUBE_BENCH_VERSION)      echo "gh:aquasecurity/kube-bench" ;;
    OSV_SCANNER_VERSION)     echo "gh:google/osv-scanner" ;;
    NERDFONTS_VERSION)       echo "gh:ryanoasis/nerd-fonts" ;;
    GO_VERSION)              echo "godev" ;;
    MCP_FILESYSTEM_VERSION)  echo "npm:@modelcontextprotocol/server-filesystem" ;;
    MCP_MEMORY_VERSION)      echo "npm:@modelcontextprotocol/server-memory" ;;
    MCP_BRAVE_VERSION)       echo "npm:@brave/brave-search-mcp-server" ;;
    MCP_FETCH_VERSION)       echo "pypi:mcp-server-fetch" ;;
    MCP_GITHUB_VERSION)      echo "gh:github/github-mcp-server" ;;
    MCP_INSPECTOR_VERSION)   echo "npm:@modelcontextprotocol/inspector" ;;
    *)                       return 1 ;;
  esac
}

# ─── Lookups ─────────────────────────────────────────────────────────────────
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

gh_get() {   # <api path> -> JSON on stdout
  if command -v gh >/dev/null 2>&1 && { [ -n "$TOKEN" ] || gh auth status >/dev/null 2>&1; }; then
    GH_TOKEN="${TOKEN:-${GH_TOKEN:-}}" gh api "$1" 2>/dev/null
  elif [ -n "$TOKEN" ]; then
    curl -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/$1" 2>/dev/null
  else
    curl -fsS --max-time 20 -H "Accept: application/vnd.github+json" "https://api.github.com/$1" 2>/dev/null
  fi
}

# Highest-first filter: keep tags whose major version is <= $1 (0 = no cap)
latest_gh() {   # <owner/repo> [max-major]
  local repo=$1 cap=${2:-0} tags
  tags="$(gh_get "repos/$repo/releases?per_page=40" | jq -r '.[] | select(.draft==false and .prerelease==false) | .tag_name' 2>/dev/null)"
  if [ -z "$tags" ]; then
    tags="$(gh_get "repos/$repo/tags?per_page=40" | jq -r '.[].name' 2>/dev/null)"
  fi
  [ -n "$tags" ] || return 1
  printf '%s\n' "$tags" | while IFS= read -r t; do
    major="${t#v}"; major="${major%%.*}"
    case "$major" in ''|*[!0-9]*) continue ;; esac
    # skip pre-release looking tags
    case "$t" in *-rc*|*-beta*|*-alpha*|*-pre*|*nightly*) continue ;; esac
    if [ "$cap" -eq 0 ] || [ "$major" -le "$cap" ]; then echo "$t"; fi
  done | head -n 1
}

latest_npm() {
  curl -fsS --max-time 20 "https://registry.npmjs.org/$(printf '%s' "$1" | sed 's#/#%2F#g')/latest" 2>/dev/null | jq -r '.version // empty'
}
latest_pypi() {
  curl -fsS --max-time 20 "https://pypi.org/pypi/$1/json" 2>/dev/null | jq -r '.info.version // empty'
}
latest_godev() {
  curl -fsS --max-time 20 "https://go.dev/dl/?mode=json" 2>/dev/null | jq -r '[.[] | select(.stable==true)][0].version // empty' | sed 's/^go//'
}

# True (0) when $1 is strictly older than $2 (leading v ignored, sort -V order)
is_behind() {
  local a="${1#v}" b="${2#v}" first
  [ "$a" = "$b" ] && return 1
  first="$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n 1)"
  [ "$first" = "$a" ]
}

# ─── Main ────────────────────────────────────────────────────────────────────
rows=""; behind=0; unknown=0; checked=0
unmapped=""

add_row() { rows="${rows}| $1 | $2 | $3 | $4 | $5 |"$'\n'; }

pins="$(sed -nE 's/^[[:space:]]*([A-Z0-9_]+_(VERSION|TAG))="([^"]*)".*/\1 \3/p' "${FILES[@]}" | grep -v ' @@')"   # drop template placeholders such as "@@INSPECTOR@@"

while read -r var current; do
  [ -n "$var" ] || continue
  if ! src="$(source_for "$var")"; then unmapped="$unmapped $var"; continue; fi
  latest=""; label=""
  case "$src" in
    gh:*)   spec="${src#gh:}"; repo="${spec%%:*}"; cap=0; [ "$repo" != "$spec" ] && cap="${spec#*:}"
            label="github.com/$repo"; latest="$(latest_gh "$repo" "$cap")" ;;
    npm:*)  label="npm ${src#npm:}";   latest="$(latest_npm "${src#npm:}")" ;;
    pypi:*) label="PyPI ${src#pypi:}"; latest="$(latest_pypi "${src#pypi:}")" ;;
    godev)  label="go.dev";            latest="$(latest_godev)" ;;
    skip:*) add_row "$var" "$current" "-" "-" "skipped: ${src#skip:}"; continue ;;
  esac
  checked=$((checked + 1))
  if [ -z "$latest" ]; then
    unknown=$((unknown + 1)); add_row "$var" "$current" "?" "$label" "lookup failed"
  elif is_behind "$current" "$latest"; then
    behind=$((behind + 1)); add_row "$var" "$current" "$latest" "$label" "BEHIND"
  else
    add_row "$var" "$current" "$latest" "$label" "ok"
  fi
done <<EOF
$pins
EOF

report="| Pin | Current | Latest | Source | Status |
|---|---|---|---|---|
${rows}
Checked $checked pins: $behind behind, $unknown lookup failures."

printf '%s\n' "$report"
if [ -n "${PINS_REPORT:-}" ]; then printf '%s\n' "$report" > "$PINS_REPORT"; fi
if [ -n "$unmapped" ]; then
  echo "check-pins: no upstream mapping for:$unmapped (add them to source_for)" >&2
fi

[ "$behind" -eq 0 ]
