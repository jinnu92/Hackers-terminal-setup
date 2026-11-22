#!/usr/bin/env bash
# =============================================================================
#  lib/ai_mcp.sh — Preconfigured Safe MCP Server Suite & AI Integrations
# =============================================================================

# ─── Pinned MCP server versions (bump deliberately; nothing floats to latest) ─
# Verified against the registries on 2026-11-22.
MCP_FILESYSTEM_VERSION="2.4.0"     # npm  @modelcontextprotocol/server-filesystem (maintained)
MCP_MEMORY_VERSION="2.2.1"         # npm  @modelcontextprotocol/server-memory     (maintained)
MCP_BRAVE_VERSION="2.2.0"          # npm  @brave/brave-search-mcp-server (replaces deprecated @modelcontextprotocol/server-brave-search)
MCP_FETCH_VERSION="2026.11.18"     # PyPI mcp-server-fetch, run via uvx (npm "@modelcontextprotocol/server-fetch" does not exist)
MCP_GITHUB_VERSION="2.2.0"         # github-mcp-server release binary (replaces archived @modelcontextprotocol/server-github)
MCP_INSPECTOR_VERSION="2.16.0"     # npm  @modelcontextprotocol/inspector

# SHA-256 of the github-mcp-server v2.2.0 release tarballs (from the release checksums file)
MCP_GITHUB_SHA_DARWIN_ARM64="5e46b05b87989d23267f0a69ee60a3acd1de51a72512ee5fcc2786ca60c54a6a"
MCP_GITHUB_SHA_DARWIN_X86_64="a42e667b99915cf368b92aa419fd2f753549ea7133cb3572a3e7f3e2d4a8675b"
MCP_GITHUB_SHA_LINUX_ARM64="d21e4fca8603b59d99380f1c332aaea36d73033d52b389867adf2124ee150983"
MCP_GITHUB_SHA_LINUX_X86_64="157c5664b273e5070126d414f88cbab765630acde588f75dafdf9998c2235c51"

# Filesystem scope. The filesystem server is ONLY ever given ~/workspace and
# ~/pentest (see _mcp_server_json). $HOME itself or / is never passed to it;
# _mcp_check_scope enforces this before any config is written.

# Servers this tool owns in the config files. Only these keys are added or
# replaced; every other server and setting in the user's files is preserved.
MCP_MANAGED_SERVERS="filesystem memory fetch github brave-search"

# Why these launch methods:
#  - filesystem, memory: still maintained under @modelcontextprotocol -> npx, pinned.
#  - fetch: Python package mcp-server-fetch -> uvx, pinned with ==.
#  - brave-search: Brave's own npm package, stdio transport.
#  - github: GitHub's server needs Docker, the hosted remote endpoint (Claude
#    Desktop config files cannot speak remote HTTP without a bridge), or the Go
#    binary. We download the pinned, checksum-verified release binary into
#    ~/.local/bin and run "github-mcp-server stdio": no Docker, works in both
#    Claude Code and Claude Desktop config files.
#  - API keys are never written to config. github-mcp-server and the Brave
#    server read GITHUB_PERSONAL_ACCESS_TOKEN / BRAVE_API_KEY from the
#    environment of the process that launches them, so entries carry no env
#    block. The github and brave-search entries are only written when the
#    variable is set at install time (otherwise they would start half-configured).

install_ai_llm() {
  step "AI / LLM security tools"

  # Python tools
  local tool
  for tool in garak llm jwt_tool; do
    pipx_install "$tool"
    if command -v "$tool" &>/dev/null; then hts_manifest_add tool "$tool" pipx; fi
  done

  # Node & npm tools
  command -v node &>/dev/null || install_node
  npm_global_install promptfoo
  if command -v promptfoo &>/dev/null; then hts_manifest_add tool promptfoo npm; fi

  # Ollama — local LLM runtime
  if ! command -v ollama &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask ollama "" "https://ollama.com"
      if command -v ollama &>/dev/null || [[ -d /Applications/Ollama.app ]]; then hts_manifest_add tool ollama brew; fi
    else
      log "Installing Ollama..."
      if hts_run_remote_script https://ollama.com/install.sh "sh"; then
        hts_manifest_add tool ollama install-script
      else
        warn "Ollama install failed"
      fi
    fi
  else
    info "Ollama already installed"
  fi

  ok "AI/LLM security done"
}

# ─── JSON helpers ─────────────────────────────────────────────────────────────

# Escape a string for use inside a JSON string literal.
_mcp_jstr() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

# Resolve a launcher to an absolute path (GUI apps like Claude Desktop have a
# minimal PATH); fall back to the bare name.
_mcp_cmd_path() {
  local p
  p="$(command -v "$1" 2>/dev/null || true)"
  if [[ -n "$p" && "$p" == /* ]]; then printf '%s' "$p"; else printf '%s' "$1"; fi
}

# Refuse to continue if the filesystem scope would ever include $HOME or /.
_mcp_check_scope() {
  local d
  for d in "$@"; do
    case "$d" in
      ""|"/"|"$HOME"|"$HOME/")
        err "Refusing to expose '$d' to the filesystem MCP server"
        return 1 ;;
    esac
  done
  return 0
}

# _mcp_server_json <name> <scope: desktop|project>
# Prints one server entry as JSON. Prints nothing (rc 1) if it cannot be offered.
_mcp_server_json() {
  local name=$1 scope=${2:-desktop} ws pt
  ws="$(_mcp_jstr "$HOME/workspace")"
  pt="$(_mcp_jstr "$HOME/pentest")"
  case "$name" in
    filesystem)
      if [[ "$scope" == "project" ]]; then
        printf '{"command":"%s","args":["-y","@modelcontextprotocol/server-filesystem@%s","%s"]}' \
          "$(_mcp_jstr "$(_mcp_cmd_path npx)")" "$MCP_FILESYSTEM_VERSION" "$pt"
      else
        printf '{"command":"%s","args":["-y","@modelcontextprotocol/server-filesystem@%s","%s","%s"]}' \
          "$(_mcp_jstr "$(_mcp_cmd_path npx)")" "$MCP_FILESYSTEM_VERSION" "$ws" "$pt"
      fi ;;
    memory)
      printf '{"command":"%s","args":["-y","@modelcontextprotocol/server-memory@%s"]}' \
        "$(_mcp_jstr "$(_mcp_cmd_path npx)")" "$MCP_MEMORY_VERSION" ;;
    fetch)
      command -v uvx &>/dev/null || return 1
      printf '{"command":"%s","args":["mcp-server-fetch==%s"]}' \
        "$(_mcp_jstr "$(_mcp_cmd_path uvx)")" "$MCP_FETCH_VERSION" ;;
    github)
      [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] || return 1
      [[ -x "$HOME/.local/bin/github-mcp-server" ]] || return 1
      printf '{"command":"%s","args":["stdio"]}' "$(_mcp_jstr "$HOME/.local/bin/github-mcp-server")" ;;
    brave-search)
      [[ -n "${BRAVE_API_KEY:-}" ]] || return 1
      printf '{"command":"%s","args":["-y","@brave/brave-search-mcp-server@%s","--transport","stdio"]}' \
        "$(_mcp_jstr "$(_mcp_cmd_path npx)")" "$MCP_BRAVE_VERSION" ;;
    *) return 1 ;;
  esac
}

# _mcp_entries_json <scope> <name...> — print {"name":{...},...}
_mcp_entries_json() {
  local scope=$1; shift
  local n e out="" sep=""
  for n in "$@"; do
    e="$(_mcp_server_json "$n" "$scope")" || continue
    out="${out}${sep}\"${n}\":${e}"
    sep=","
  done
  printf '{%s}' "$out"
}

# _mcp_side_file <config> <entries-file> <side-file>
_mcp_side_file() {
  local cfg=$1 entries=$2 side=$3
  if cp "$entries" "$side" 2>/dev/null; then hts_track_file "$side"; fi
  warn "Could not merge into $cfg (left unchanged). This tool's entries were written to:"
  warn "  $side"
  warn "Copy the entries inside it into the \"mcpServers\" object of $cfg by hand."
}

# _mcp_merge_file <config> <entries-json-file>
# Backs up the config, then adds/replaces only the managed entries under
# "mcpServers", keeping everything else. Uses python3, else jq. Never writes
# invalid JSON; on an unparsable existing file or no JSON tool, leaves the
# original untouched and writes the entries beside it for manual merging.
_mcp_merge_file() {
  local cfg=$1 entries=$2 tmp side
  side="${cfg}.hts-mcp-servers.json"
  tmp="$(mktemp "${TMPDIR:-/tmp}/hts-mcp.XXXXXX")" || return 1
  backup_file "$cfg"

  if command -v python3 &>/dev/null; then
    if ! python3 - "$cfg" "$entries" "$tmp" 2>/dev/null <<'PY'
import json, os, sys
cfg, entries, out = sys.argv[1:4]
doc = {}
if os.path.exists(cfg) and os.path.getsize(cfg) > 0:
    with open(cfg) as f:
        txt = f.read()
    if txt.strip():
        doc = json.loads(txt)
if not isinstance(doc, dict):
    raise SystemExit("config root is not a JSON object")
with open(entries) as f:
    new = json.load(f)
servers = doc.get("mcpServers")
if not isinstance(servers, dict):
    servers = {}
servers.update(new)
# Drop leftovers that launch packages which no longer exist or are archived.
DEAD = ("@modelcontextprotocol/server-github",
        "@modelcontextprotocol/server-brave-search",
        "@modelcontextprotocol/server-fetch")
def launches_dead(entry):
    if not isinstance(entry, dict):
        return False
    for arg in entry.get("args") or []:
        if isinstance(arg, str) and any(arg == d or arg.startswith(d + "@") for d in DEAD):
            return True
    return False
for name in [n for n, e in servers.items() if n not in new and launches_dead(e)]:
    del servers[name]
doc["mcpServers"] = servers
with open(out, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
    then
      rm -f "$tmp"
      _mcp_side_file "$cfg" "$entries" "$side"
      return 1
    fi
  elif command -v jq &>/dev/null; then
    local base="$cfg"
    if [[ ! -s "$cfg" ]]; then base="$tmp.empty"; echo '{}' > "$base"; fi
    # Same rule as the python path: merge, then drop leftovers that launch dead packages
    if ! jq --slurpfile new "$entries" '
        def dead: ["@modelcontextprotocol/server-github", "@modelcontextprotocol/server-brave-search", "@modelcontextprotocol/server-fetch"];
        def launches_dead: ((.args // []) | map(select(type == "string")) | any(. as $a | dead | any(. as $d | $a == $d or ($a | startswith($d + "@")))));
        .mcpServers = (((.mcpServers // {}) + $new[0])
          | with_entries(select((.key as $k | $new[0] | has($k)) or ((.value | launches_dead) | not))))
      ' "$base" > "$tmp" 2>/dev/null; then
      rm -f "$tmp" "$tmp.empty"
      _mcp_side_file "$cfg" "$entries" "$side"
      return 1
    fi
    rm -f "$tmp.empty"
  else
    rm -f "$tmp"
    warn "Neither python3 nor jq is available; cannot merge $cfg safely"
    _mcp_side_file "$cfg" "$entries" "$side"
    return 1
  fi

  # Final validation before replacing the user's file
  if command -v python3 &>/dev/null; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" 2>/dev/null \
      || { rm -f "$tmp"; err "Merged JSON failed validation; $cfg left unchanged"; return 1; }
  else
    jq -e . "$tmp" >/dev/null 2>&1 \
      || { rm -f "$tmp"; err "Merged JSON failed validation; $cfg left unchanged"; return 1; }
  fi
  cat "$tmp" > "$cfg" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  hts_track_file "$cfg"
  return 0
}

# Register servers with Claude Code at user scope (~/.claude.json) so they are
# available in every project. Replaces only the entries this tool manages.
_mcp_register_claude_code() {
  if ! command -v claude &>/dev/null; then
    info "claude CLI not found; skipping Claude Code user-level registration"
    return 0
  fi
  local n e failed=0
  for n in "$@"; do
    e="$(_mcp_server_json "$n" desktop)" || continue
    claude mcp remove --scope user "$n" &>/dev/null || true
    if claude mcp add-json --scope user "$n" "$e" &>/dev/null; then
      info "Claude Code (user scope): registered $n"
    else
      warn "Could not register $n with Claude Code; try: claude mcp add-json --scope user $n '<json>'"
      failed=1
    fi
  done
  return $failed
}

# Download the pinned, checksum-verified GitHub MCP server binary.
_mcp_install_github_server() {
  local dest="$HOME/.local/bin/github-mcp-server" os arch sha tmpd
  if [[ -x "$dest" ]] && "$dest" --version 2>/dev/null | grep -q "$MCP_GITHUB_VERSION"; then
    info "github-mcp-server $MCP_GITHUB_VERSION already installed"
    return 0
  fi
  case "$(uname -s)" in Darwin) os=Darwin ;; Linux) os=Linux ;; *) return 1 ;; esac
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64)  arch=x86_64 ;;
    *) warn "No github-mcp-server build for $(uname -m)"; return 1 ;;
  esac
  case "${os}_${arch}" in
    Darwin_arm64)  sha="$MCP_GITHUB_SHA_DARWIN_ARM64" ;;
    Darwin_x86_64) sha="$MCP_GITHUB_SHA_DARWIN_X86_64" ;;
    Linux_arm64)   sha="$MCP_GITHUB_SHA_LINUX_ARM64" ;;
    Linux_x86_64)  sha="$MCP_GITHUB_SHA_LINUX_X86_64" ;;
    *) return 1 ;;
  esac
  tmpd="$(mktemp -d "${TMPDIR:-/tmp}/hts-ghmcp.XXXXXX")" || return 1
  log "Installing github-mcp-server $MCP_GITHUB_VERSION..."
  if hts_download_verify "https://github.com/github/github-mcp-server/releases/download/v${MCP_GITHUB_VERSION}/github-mcp-server_${os}_${arch}.tar.gz" "$sha" "$tmpd/gh.tgz" \
     && tar -xzf "$tmpd/gh.tgz" -C "$tmpd" github-mcp-server \
     && mkdir -p "$HOME/.local/bin" \
     && install -m 755 "$tmpd/github-mcp-server" "$dest"; then
    rm -rf "$tmpd"
    hts_track_file "$dest"
    hts_manifest_add tool github-mcp-server release-binary
    return 0
  fi
  rm -rf "$tmpd"
  warn "github-mcp-server install failed"
  return 1
}

setup_mcp_suite() {
  step "Preconfigured Safe MCP Server Suite (Claude Code & Claude Desktop)"
  local rc=0

  command -v node &>/dev/null || install_node

  # MCP Inspector (pinned) and security scanners
  if ! command -v mcp-inspector &>/dev/null; then
    if ! hts_node_managed >/dev/null; then
      mkdir -p "$HOME/.npm-global"
      npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
      export PATH="$HOME/.npm-global/bin:$PATH"
    fi
    if npm install -g "@modelcontextprotocol/inspector@${MCP_INSPECTOR_VERSION}"; then
      hts_manifest_add tool "@modelcontextprotocol/inspector@${MCP_INSPECTOR_VERSION}" npm
    else
      warn "npm install -g inspector failed"
    fi
  fi
  if ! pipx_install semgrep 2>/dev/null; then pkg_install semgrep; fi
  if command -v semgrep &>/dev/null; then hts_manifest_add tool semgrep pipx; fi
  pipx_install detect-secrets
  if command -v detect-secrets &>/dev/null; then hts_manifest_add tool detect-secrets pipx; fi

  # uvx (from uv) runs the Python fetch server
  if ! command -v uvx &>/dev/null; then
    pipx_install uv
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uvx &>/dev/null; then hts_manifest_add tool uv pipx; fi
  fi
  command -v uvx &>/dev/null || warn "uvx not available: the fetch server will be skipped"

  # GitHub server binary only if the user has a token to use it with
  if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    _mcp_install_github_server || rc=1
  fi

  # 1. Sandboxed project directories (NEVER expose $HOME or /)
  local workspace_dir="$HOME/workspace"
  local pentest_dir="$HOME/pentest"
  _mcp_check_scope "$workspace_dir" "$pentest_dir" || return 1
  mkdir -p "$workspace_dir" "$pentest_dir"

  # 2. Which servers can be configured right now
  local n active="" skipped=""
  for n in $MCP_MANAGED_SERVERS; do
    if _mcp_server_json "$n" desktop >/dev/null 2>&1; then
      active="$active $n"
    else
      skipped="$skipped $n"
    fi
  done

  local claude_cfg_file
  if [[ "$OS" == "Darwin" ]]; then
    claude_cfg_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  else
    claude_cfg_file="$HOME/.config/Claude/claude_desktop_config.json"
  fi
  mkdir -p "$(dirname "$claude_cfg_file")"

  local ef
  ef="$(mktemp "${TMPDIR:-/tmp}/hts-mcp-entries.XXXXXX")" || return 1
  # shellcheck disable=SC2086
  _mcp_entries_json desktop $active > "$ef"

  log "Merging MCP servers into Claude Desktop config (existing servers and settings are kept)..."
  if _mcp_merge_file "$claude_cfg_file" "$ef"; then
    ok "Claude Desktop MCP configuration updated: $claude_cfg_file"
  else
    rc=1
  fi

  # 3. Project-level .mcp.json for ~/pentest (filesystem limited to ~/pentest)
  local project_mcp="$pentest_dir/.mcp.json" pactive=""
  for n in filesystem fetch memory; do
    case " $active " in *" $n "*) pactive="$pactive $n" ;; esac
  done
  # shellcheck disable=SC2086
  _mcp_entries_json project $pactive > "$ef"
  if _mcp_merge_file "$project_mcp" "$ef"; then
    ok "Project MCP config updated: $project_mcp"
  else
    rc=1
  fi
  rm -f "$ef"

  # 4. Claude Code user-level registration
  # shellcheck disable=SC2086
  _mcp_register_claude_code $active || rc=1

  # 5. sec-mcp helper
  _mcp_install_secmcp || rc=1

  # 6. One post-install note about keys
  case " $skipped " in
    *" github "*|*" brave-search "*)
      info "API keys: export the variables below in your shell profile, then run 'sec-mcp setup':"
      case " $skipped " in *" github "*) info "  export GITHUB_PERSONAL_ACCESS_TOKEN=...   (enables the github server)" ;; esac
      case " $skipped " in *" brave-search "*) info "  export BRAVE_API_KEY=...                  (enables the brave-search server)" ;; esac
      info "  Keys are never stored in the config files. Claude Desktop only sees variables it was"
      info "  launched with (macOS: 'launchctl setenv NAME value', then restart the app)." ;;
  esac
  case " $skipped " in *" fetch "*) info "Skipped: fetch (needs uvx; install uv, then run 'sec-mcp setup')" ;; esac
  info "Configured servers:$active"
  return $rc
}

_mcp_install_secmcp() {
  local dest="$HOME/.local/bin/sec-mcp" self="" esc
  mkdir -p "$HOME/.local/bin" || return 1
  backup_file "$dest"
  # Remember the installer so 'sec-mcp setup' can re-run it (only if run from a file)
  self="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]:-}"
  if [[ -f "$self" && "$(basename "$self")" == "ter.sh" ]]; then
    self="$(cd "$(dirname "$self")" && pwd)/$(basename "$self")"
  else
    self=""
  fi
  esc="${self//\\/\\\\}"; esc="${esc//&/\\&}"; esc="${esc//|/\\|}"
  cat > "$dest" << 'SECMCP'
#!/usr/bin/env bash
# =============================================================================
# sec-mcp — Security MCP Suite Manager
#   list     show the servers actually present in your config files
#   inspect  launch the MCP Inspector (pinned version)
#   setup    re-run the MCP configuration (merges; keeps your other servers)
# =============================================================================
HTS_INSTALLER="@@INSTALLER@@"
INSPECTOR_VERSION="@@INSPECTOR@@"

if [[ "$(uname -s)" == "Darwin" ]]; then
  DESKTOP_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
else
  DESKTOP_CFG="$HOME/.config/Claude/claude_desktop_config.json"
fi

# _show <label> <file> — print the servers of one config file
_show() {
  local label=$1 file=$2
  echo -e "\033[1;36m$label\033[0m  ($file)"
  if [[ ! -f "$file" ]]; then echo "  (file not found)"; return; fi
  if command -v python3 &>/dev/null; then
    python3 - "$file" <<'PY'
import json, os, sys
home = os.path.expanduser("~")
try:
    doc = json.load(open(sys.argv[1]))
except Exception as e:
    print("  (unreadable JSON: %s)" % e); sys.exit(0)
servers = doc.get("mcpServers") or {}
if not servers:
    print("  (no MCP servers)")
for name, s in servers.items():
    cmd = s.get("command") or s.get("url") or "?"
    args = [str(a) for a in s.get("args", [])]
    print("  [x] %-13s %s %s" % (name, os.path.basename(cmd), " ".join(args)))
    if "filesystem" in name or any("server-filesystem" in a for a in args):
        dirs = [a for a in args if a.startswith("/")]
        print("      filesystem scope: %s" % (", ".join(dirs) or "(none)"))
        if any(d.rstrip("/") in (home, "") for d in dirs):
            print("      WARNING: scope includes your whole home directory or /")
    if name == "github" and not os.environ.get("GITHUB_PERSONAL_ACCESS_TOKEN"):
        print("      note: GITHUB_PERSONAL_ACCESS_TOKEN is not set in this shell")
    if name == "brave-search" and not os.environ.get("BRAVE_API_KEY"):
        print("      note: BRAVE_API_KEY is not set in this shell")
PY
  elif command -v jq &>/dev/null; then
    jq -r '(.mcpServers // {}) | to_entries[] | "  [x] \(.key)  \(.value.command // .value.url) \((.value.args // []) | join(" "))"' "$file" 2>/dev/null || echo "  (unreadable JSON)"
  else
    echo "  (python3 or jq required to read this file)"
  fi
}

case "$1" in
  list|ls)
    _show "Claude Desktop" "$DESKTOP_CFG"
    _show "Project (~/pentest)" "$HOME/pentest/.mcp.json"
    if [[ -f "$HOME/.claude.json" ]]; then
      _show "Claude Code (user scope)" "$HOME/.claude.json"
    fi
    ;;
  inspect)
    echo -e "\033[1;36mLaunching MCP Inspector UI...\033[0m"
    npx -y "@modelcontextprotocol/inspector@${INSPECTOR_VERSION}"
    ;;
  setup)
    echo -e "\033[1;36mRe-running MCP Suite setup...\033[0m"
    if [[ -n "$HTS_INSTALLER" && -f "$HTS_INSTALLER" ]]; then
      bash "$HTS_INSTALLER" --mcp
    else
      echo "The original installer path is unknown. Re-run the installer with: ter.sh --mcp"
      exit 1
    fi
    ;;
  *)
    echo "Usage: sec-mcp {list|inspect|setup}"
    echo "  list     show servers in your Claude Desktop / project / Claude Code config"
    echo "  inspect  launch the MCP Inspector"
    echo "  setup    re-run MCP configuration via the installer (--mcp)"
    ;;
esac
SECMCP
  sed -i.bak -e "s|@@INSTALLER@@|${esc}|" -e "s|@@INSPECTOR@@|${MCP_INSPECTOR_VERSION}|" "$dest" && rm -f "$dest.bak"
  chmod +x "$dest"
  hts_track_file "$dest"
  hts_manifest_add tool sec-mcp script
  ok "sec-mcp management CLI installed to ~/.local/bin/sec-mcp"
}

install_mcp() {
  setup_mcp_suite
}
