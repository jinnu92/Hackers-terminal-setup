#!/usr/bin/env bash
# =============================================================================
#  lib/lifecycle.sh — --status, --restore, --uninstall, --purge-tools, --update
#  Reads the manifest written by backup_file / hts_track_file / hts_manifest_add:
#    epoch<TAB>kind<TAB>name<TAB>detail   (kind: component|tool|file|backup)
# =============================================================================

HTS_REPO_SLUG="jinnu92/Hackers-terminal-setup"
_LC_US=$'\037'

# ─── Argument parsing ─────────────────────────────────────────────────────────
# Sets HTS_LC_CMD (status|restore|uninstall|update|""), HTS_LC_TS, HTS_LC_PURGE,
# HTS_LC_DRY, HTS_LC_YES, HTS_DOCTOR_FORMAT and the array HTS_PASSTHRU (all args
# that are not lifecycle flags / --json). Returns non-zero on invalid usage.
hts_lifecycle_parse() {
  HTS_LC_CMD=""; HTS_LC_TS=""; HTS_LC_PURGE=0; HTS_LC_DRY=0; HTS_LC_YES=0
  HTS_PASSTHRU=()
  local cmds="" a nxt rest="" bad="" ncmd=0 args=("$@") i=0 n=$#
  case "${1:-}" in -h|--help|help) HTS_PASSTHRU=("$@"); return 0 ;; esac
  while [[ $i -lt $n ]]; do
    a="${args[$i]}"; i=$((i+1))
    case "$a" in
      --status|--uninstall|--update) cmds="$cmds ${a#--}"; ncmd=$((ncmd+1)) ;;
      --restore)
        cmds="$cmds restore"; ncmd=$((ncmd+1))
        if [[ $i -lt $n ]]; then
          nxt="${args[$i]}"
          case "$nxt" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*) HTS_LC_TS="$nxt"; i=$((i+1)) ;; esac
        fi ;;
      --purge-tools) HTS_LC_PURGE=1 ;;
      --json)        HTS_DOCTOR_FORMAT=json; export HTS_DOCTOR_FORMAT ;;
      -y|--yes)      HTS_LC_YES=1; HTS_PASSTHRU+=("$a") ;;
      -n|--dry-run)  HTS_LC_DRY=1; HTS_PASSTHRU+=("$a") ;;
      *)             rest="$rest $a"; HTS_PASSTHRU+=("$a") ;;
    esac
  done
  if [[ $ncmd -eq 0 ]]; then
    if [[ "$HTS_LC_PURGE" == "1" ]]; then err "--purge-tools only works together with --uninstall"; return 1; fi
    return 0
  fi
  if [[ $ncmd -gt 1 ]]; then err "Only one lifecycle command allowed at a time (got:$cmds)"; return 1; fi
  HTS_LC_CMD="${cmds# }"
  if [[ "$HTS_LC_PURGE" == "1" && "$HTS_LC_CMD" != "uninstall" ]]; then
    err "--purge-tools only works together with --uninstall"; return 1
  fi
  if [[ -n "$rest" ]]; then
    bad="${rest# }"
    err "Lifecycle command --$HTS_LC_CMD cannot be combined with other options or component selections: $bad"
    return 1
  fi
  HTS_PASSTHRU=()
  return 0
}

# True when the arguments ask only for the doctor (keeps --json output clean).
hts_doctor_only_args() {
  local a low seen=0
  [[ $# -gt 0 ]] || return 1
  for a in "$@"; do
    low="$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')"
    case "$low" in
      -y|--yes|y|yes) ;;
      *) [[ "$(hts_resolve_token "$low" 2>/dev/null)" == "doctor" ]] || return 1; seen=1 ;;
    esac
  done
  [[ $seen -eq 1 ]]
}

# ─── Safety helpers ───────────────────────────────────────────────────────────
_lc_rows() {   # file kind -> epoch US name US detail
  [[ -f "$1" ]] || return 0
  awk -F'\t' -v k="$2" 'BEGIN{OFS="\037"} /^[[:space:]]*#/ {next} NF>=3 && $2==k {print $1,$3,$4}' "$1"
}

# Validate a manifest path for touching. Sets _LC_PATH (normalised) / _LC_REASON.
_lc_validate_path() {
  local p=$1 home parent realp realhome rel
  _LC_PATH=""; _LC_REASON=""
  home="${HOME%/}"
  if [[ -z "$home" || "$home" != /* ]]; then _LC_REASON="HOME is unset or not absolute"; return 1; fi
  if [[ -z "$p" ]]; then _LC_REASON="empty path"; return 1; fi
  if [[ "$p" != /* ]]; then _LC_REASON="not an absolute path"; return 1; fi
  case "$p" in *$'\n'*|*$'\r'*|*$'\t'*) _LC_REASON="control characters in path"; return 1 ;; esac
  case "/$p/" in */../*|*/./*) _LC_REASON="contains '..' or '.' component"; return 1 ;; esac
  while [[ "$p" == */ && "$p" != "/" ]]; do p="${p%/}"; done
  if [[ "$p" == "$home" ]]; then _LC_REASON="is \$HOME itself"; return 1; fi
  case "$p" in "$home"/?*) ;; *) _LC_REASON="outside \$HOME"; return 1 ;; esac
  rel="${p#"$home"/}"
  if [[ "$rel" != */* && -d "$p" && ! -L "$p" ]]; then
    _LC_REASON="top-level directory of \$HOME (may hold your work) — left in place"; return 1
  fi
  parent="$(dirname "$p")"
  if [[ -d "$parent" ]]; then
    realp="$(cd -P "$parent" 2>/dev/null && pwd -P)" || realp=""
    realhome="$(cd -P "$home" 2>/dev/null && pwd -P)" || realhome=""
    if [[ -z "$realp" || -z "$realhome" ]]; then _LC_REASON="cannot resolve parent directory"; return 1; fi
    case "$realp/" in "$realhome"/*) ;; *) _LC_REASON="resolves outside \$HOME via symlink"; return 1 ;; esac
  fi
  _LC_PATH="$p"
  return 0
}

# Directories may only be removed when they are tool clones under ~/.local/share.
_lc_dir_removable() {
  local p=$1 home="${HOME%/}"
  [[ -n "$p" && -d "$p" && ! -L "$p" ]] || return 1
  case "$p" in "$home"/.local/share/?*) return 0 ;; esac
  return 1
}
_lc_name_ok() {
  local re='^[A-Za-z0-9][A-Za-z0-9._+@/:-]*$'
  [[ -n "$1" && "$1" =~ $re ]]
}
_lc_init() {
  _LC_DRY="${HTS_LC_DRY:-0}"; _LC_YES="${HTS_LC_YES:-0}"
  _LC_OK=0; _LC_FAIL=0; _LC_REFUSED=0
  _LC_TMP="$(mktemp -d "${TMPDIR:-/tmp}/hts-lc.XXXXXX")" || { err "cannot create temp dir"; return 1; }
  _LC_PLAN="$_LC_TMP/plan"; _LC_TOOLS="$_LC_TMP/tools"
  if [[ -z "${HOME:-}" || "$HOME" != /* || "${HOME%/}" == "" ]]; then
    err "HOME is unset or invalid — refusing to continue"; return 1
  fi
}
_lc_cleanup() {
  case "${_LC_TMP:-}" in */hts-lc.??????) rm -rf "$_LC_TMP" ;; esac
}
_lc_confirm() {   # returns 0 proceed, 1 declined, 2 refused (no terminal)
  local ans=""
  [[ "$_LC_DRY" == "1" || "$_LC_YES" == "1" ]] && return 0
  if [[ -t 0 ]]; then
    read -r -p "$1 [y/N] " ans || ans=""
  elif [[ "${_HTS_PIPED:-0}" == "1" ]] && { exec 3</dev/tty; } 2>/dev/null; then
    printf '%s [y/N] ' "$1" >&2; read -r ans <&3 || ans=""; exec 3<&-
  else
    err "Confirmation required but stdin is not a terminal. Re-run with -y to proceed unattended."
    return 2
  fi
  case "$ans" in y|Y|yes|YES) return 0 ;; esac
  info "Aborted — nothing changed."; return 1
}
_lc_exec() {   # desc cmd...
  local desc=$1; shift
  if [[ "$_LC_DRY" == "1" ]]; then echo -e "  ${DIM}[dry-run]${RESET} $desc: $*"; return 0; fi
  local rc=0
  run_step "$desc" "$@" </dev/null || rc=$?
  set +e   # run_step re-enables errexit
  if [[ $rc -eq 0 ]]; then _LC_OK=$((_LC_OK+1)); else _LC_FAIL=$((_LC_FAIL+1)); return 1; fi
}
_lc_summary() {
  echo ""
  if [[ "$_LC_DRY" == "1" ]]; then info "Dry run — no changes were made."; return 0; fi
  if [[ ${#HTS_RES_STATUS[@]} -gt 0 ]]; then hts_print_summary || true; fi
  echo -e "  ${GREEN}$_LC_OK ok${RESET}, ${RED}$_LC_FAIL failed${RESET}, ${YELLOW}$_LC_REFUSED refused/skipped${RESET}"
  [[ "$_LC_FAIL" -eq 0 ]]
}

# ─── Backup plan: earliest backup per original path (optionally one run only) ─
_lc_build_plan() {   # [timestamp]
  local want="${1:-}" raw="$_LC_TMP/raw" f epoch orig detail ts rel
  : > "$raw"
  for f in "$HTS_MANIFEST" "$HTS_MANIFEST".uninstalled-*; do
    [[ -f "$f" ]] || continue
    while IFS="$_LC_US" read -r epoch orig detail; do
      [[ -n "$orig" && -n "$detail" ]] || continue
      case "$detail" in "$HTS_BACKUP_ROOT"/*) ;; *) continue ;; esac
      case "/$detail/" in */../*) continue ;; esac
      rel="${detail#"$HTS_BACKUP_ROOT"/}"; ts="${rel%%/*}"
      [[ -n "$ts" ]] || continue
      case "$epoch" in ''|*[!0-9]*) epoch=0 ;; esac
      printf '%s\037%s\037%s\037%s\n' "$epoch" "$ts" "$orig" "$detail" >> "$raw"
    done < <(_lc_rows "$f" backup)
  done
  sort -t "$_LC_US" -k1,1n -s "$raw" | awk -F "$_LC_US" -v want="$want" '(want=="" || $2==want) && !seen[$3]++' > "$_LC_PLAN"
}

# Restore one backed-up file. Backs up the current file first (reversible).
_lc_restore_one() {   # original backup
  local orig=$1 bak=$2
  if ! _lc_validate_path "$orig"; then
    warn "refused $orig — $_LC_REASON"; _LC_REFUSED=$((_LC_REFUSED+1)); return 1
  fi
  orig="$_LC_PATH"
  if [[ ! -e "$bak" && ! -L "$bak" ]]; then
    warn "backup missing for $orig ($bak)"; _LC_FAIL=$((_LC_FAIL+1)); return 1
  fi
  if [[ -d "$bak" && ! -L "$bak" ]]; then
    warn "skipped $orig — backup is a directory (restore manually from $bak)"; _LC_REFUSED=$((_LC_REFUSED+1)); return 1
  fi
  if [[ -d "$orig" && ! -L "$orig" ]]; then
    warn "skipped $orig — now a directory"; _LC_REFUSED=$((_LC_REFUSED+1)); return 1
  fi
  if [[ "$_LC_DRY" == "1" ]]; then echo -e "  ${DIM}[dry-run]${RESET} restore $orig  <-  $bak"; return 0; fi
  if [[ -e "$orig" || -L "$orig" ]]; then
    backup_file "$orig"
    local cur
    case "$orig" in
      "${HOME%/}"/*) cur="$HTS_BACKUP_ROOT/$HTS_RUN_TS/${orig#"${HOME%/}"/}" ;;
      *)             cur="$HTS_BACKUP_ROOT/$HTS_RUN_TS/${orig#/}" ;;
    esac
    if [[ ! -e "$cur" && ! -L "$cur" ]]; then
      warn "could not back up current $orig — not overwriting"; _LC_FAIL=$((_LC_FAIL+1)); return 1
    fi
  fi
  mkdir -p "$(dirname "$orig")" || { _LC_FAIL=$((_LC_FAIL+1)); return 1; }
  _lc_exec "restore $orig" _lc_copy_over "$bak" "$orig"
}
_lc_copy_over() { rm -f -- "$2" && cp -pP -- "$1" "$2"; }

# ─── --status ─────────────────────────────────────────────────────────────────
hts_lc_status() {
  _lc_init || return 1
  local n d ts cnt any=0 f
  step "Hackers Terminal Setup — status"
  if [[ ! -s "$HTS_MANIFEST" ]]; then
    info "Nothing installed by this tool yet (no manifest at $HTS_MANIFEST)."
  else
    echo -e "  ${BOLD}Installed components:${RESET}"
    n=0
    while IFS="$_LC_US" read -r _ d ts; do
      [[ -n "$d" ]] || continue; echo "    - $d  ${ts:+($ts)}"; n=$((n+1))
    done < <(_lc_rows "$HTS_MANIFEST" component | sort -t "$_LC_US" -k2,2 -u)
    [[ $n -gt 0 ]] || echo "    (none recorded)"
    echo -e "  ${BOLD}Tracked tools:${RESET} $(_lc_rows "$HTS_MANIFEST" tool | awk -F"$_LC_US" '{print $2}' | sort -u | wc -l | tr -d ' ')"
    echo -e "  ${BOLD}Tracked files:${RESET} $(_lc_rows "$HTS_MANIFEST" file | awk -F"$_LC_US" '{print $2}' | sort -u | wc -l | tr -d ' ')"
  fi
  echo -e "  ${BOLD}Backup runs:${RESET}"
  if [[ -d "$HTS_BACKUP_ROOT" ]]; then
    for d in "$HTS_BACKUP_ROOT"/*/; do
      [[ -d "$d" ]] || continue
      ts="$(basename "$d")"; cnt="$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')"
      echo "    $ts  ($cnt files)"; any=1
    done
  fi
  [[ $any -eq 1 ]] || echo "    (none)"
  for f in "$HTS_MANIFEST".uninstalled-*; do [[ -f "$f" ]] && echo "  Archived manifest: $f"; done
  echo -e "  ${BOLD}State dir:${RESET} $HTS_STATE_DIR"
  echo -e "  ${BOLD}Manifest:${RESET}  $HTS_MANIFEST"
  echo -e "  ${BOLD}Backups:${RESET}   $HTS_BACKUP_ROOT"
  echo -e "  ${BOLD}Log:${RESET}       ${HTS_LOG:-(not set)}"
  _lc_cleanup
  return 0
}

# ─── --restore ────────────────────────────────────────────────────────────────
hts_lc_restore() {
  _lc_init || return 1
  local ts="${HTS_LC_TS:-}" epoch rts orig bak n rc=0
  step "Restore backed-up files"
  if [[ -z "$ts" ]]; then
    local runs
    runs="$(for f in "$HTS_MANIFEST" "$HTS_MANIFEST".uninstalled-*; do _lc_rows "$f" backup; done | awk -F"$_LC_US" -v r="$HTS_BACKUP_ROOT/" 'index($3,r)==1 {s=substr($3,length(r)+1); sub("/.*","",s); c[s]++} END{for(k in c) print k, c[k]}' | sort)"
    if [[ -n "$runs" ]]; then
      echo -e "  ${BOLD}Backup runs:${RESET}"; echo "$runs" | sed 's/^/    /;s/ \([0-9]*\)$/  (\1 files)/'
      info "Restoring the EARLIEST backup of each file (your pre-install original)."
    fi
  fi
  _lc_build_plan "$ts"
  n="$(wc -l < "$_LC_PLAN" | tr -d ' ')"
  if [[ "$n" -eq 0 ]]; then
    if [[ -n "$ts" ]]; then warn "No backups recorded for run '$ts'."; else info "No backups recorded — nothing to restore."; fi
    _lc_cleanup; return 0
  fi
  echo -e "  ${BOLD}Files to restore ($n):${RESET}"
  while IFS="$_LC_US" read -r epoch rts orig bak; do
    echo "    $orig   <- run $rts"
  done < "$_LC_PLAN"
  _lc_confirm "Restore these $n file(s)? Current files are backed up first." || { rc=$?; _lc_cleanup; return $rc; }
  while IFS="$_LC_US" read -r epoch rts orig bak; do
    _lc_restore_one "$orig" "$bak" || true
  done < "$_LC_PLAN"
  _lc_summary || rc=1
  _lc_cleanup
  return $rc
}

# ─── Tool grouping (uninstall / purge / update) ───────────────────────────────
_lc_collect_tools() {   # method US name US detail, unique
  local epoch name detail m
  : > "$_LC_TOOLS"
  while IFS="$_LC_US" read -r epoch name detail; do
    [[ -n "$name" ]] || continue
    m="$(printf '%s' "${detail%%:*}" | tr '[:upper:]' '[:lower:]')"; [[ -n "$m" ]] || m="unknown"
    printf '%s\037%s\037%s\n' "$m" "$name" "$detail" >> "$_LC_TOOLS"
  done < <(_lc_rows "$HTS_MANIFEST" tool)
  sort -t "$_LC_US" -k1,2 -u "$_LC_TOOLS" -o "$_LC_TOOLS"
}
_lc_names_for() {   # method -> space separated, validated names (go: binary basename)
  local m=$1 out="" mm name det
  while IFS="$_LC_US" read -r mm name det; do
    [[ "$mm" == "$m" ]] || continue
    [[ "$m" == "go" ]] && { name="${name%@*}"; name="${name##*/}"; }
    if _lc_name_ok "$name"; then out="$out $name"
    else warn "ignoring unsafe tool name in manifest: '$name'" >&2; fi
  done < "$_LC_TOOLS"
  echo "${out# }"
}
_lc_gobin() {
  local b=""
  command -v go >/dev/null 2>&1 && b="$(go env GOBIN 2>/dev/null)"
  if [[ -z "$b" ]]; then b="${GOPATH:-$HOME/go}"; b="${b%%:*}/bin"; fi
  echo "$b"
}

# _LC_MODE=print shows the command, _LC_MODE=exec runs it (honouring dry-run).
_lc_cmd() {
  local desc=$1; shift
  if [[ "$_LC_MODE" == "print" ]]; then echo "      $*"; else _lc_exec "$desc" "$@" || true; fi
}
_lc_tools_remove() {
  local m names arr x gobin
  for m in brew pipx npm apt dnf yum pacman zypper go cargo; do
    names="$(_lc_names_for "$m")"; [[ -n "$names" ]] || continue
    read -r -a arr <<< "$names"
    [[ "$_LC_MODE" == "print" ]] && echo "    $m: ${arr[*]}"
    case "$m" in
      brew)   _lc_cmd "brew uninstall" brew uninstall "${arr[@]}" ;;
      npm)    _lc_cmd "npm uninstall -g" npm uninstall -g "${arr[@]}" ;;
      apt)    _lc_cmd "apt-get remove" sudo apt-get remove -y "${arr[@]}" ;;
      dnf)    _lc_cmd "dnf remove" sudo dnf remove -y "${arr[@]}" ;;
      yum)    _lc_cmd "yum remove" sudo yum remove -y "${arr[@]}" ;;
      zypper) _lc_cmd "zypper remove" sudo zypper remove -y "${arr[@]}" ;;
      pacman) _lc_cmd "pacman -R" sudo pacman -R --noconfirm "${arr[@]}" ;;
      cargo)  _lc_cmd "cargo uninstall" cargo uninstall "${arr[@]}" ;;
      pipx)   for x in "${arr[@]}"; do _lc_cmd "pipx uninstall $x" pipx uninstall "$x"; done ;;
      go)
        gobin="$(_lc_gobin)"
        if ! _lc_validate_path "$gobin"; then
          warn "go bin dir '$gobin' rejected ($_LC_REASON) — not removing go tools"; _LC_REFUSED=$((_LC_REFUSED+1))
        else
          for x in "${arr[@]}"; do _lc_cmd "remove go binary $x" rm -f -- "$_LC_PATH/$x"; done
        fi ;;
    esac
  done
  # Anything else (direct downloads etc.) cannot be removed generically.
  while IFS="$_LC_US" read -r m x _; do
    case "$m" in brew|pipx|npm|apt|dnf|yum|pacman|zypper|go|cargo) ;; *)
      [[ "$_LC_MODE" == "print" ]] && echo "    $m: $x (no automatic removal; delete manually)" ;;
    esac
  done < "$_LC_TOOLS"
}

# ─── --uninstall ──────────────────────────────────────────────────────────────
hts_lc_uninstall() {
  _lc_init || return 1
  local epoch name detail kind rts orig bak cand="$_LC_TMP/cand" acts="$_LC_TMP/acts" p rc=0
  local n_restore=0 n_rm=0 n_skip=0 act arg extra
  step "Uninstall (conservative)"
  if [[ ! -s "$HTS_MANIFEST" ]]; then
    info "No manifest at $HTS_MANIFEST — nothing was installed by this tool. Nothing to do."
    _lc_cleanup; return 0
  fi
  _lc_build_plan ""
  # Candidates: manifest file entries (latest first so children go before parents) + backed-up paths.
  { _lc_rows "$HTS_MANIFEST" file | awk -F"$_LC_US" '{a[NR]=$2} END{for(i=NR;i>=1;i--)print a[i]}'
    awk -F"$_LC_US" '{print $3}' "$_LC_PLAN"; } | awk '!seen[$0]++' > "$cand"
  : > "$acts"
  while IFS= read -r name || [[ -n "$name" ]]; do
    if ! _lc_validate_path "$name"; then
      printf 'refuse\037%s\037%s\n' "$name" "$_LC_REASON" >> "$acts"; continue
    fi
    p="$_LC_PATH"
    bak="$(awk -F"$_LC_US" -v p="$p" '$3==p {print $4; exit}' "$_LC_PLAN")"
    if [[ -n "$bak" ]]; then printf 'restore\037%s\037%s\n' "$p" "$bak" >> "$acts"
    elif [[ ! -e "$p" && ! -L "$p" ]]; then printf 'gone\037%s\037\n' "$p" >> "$acts"
    elif [[ -d "$p" && ! -L "$p" ]]; then
      if _lc_dir_removable "$p"; then printf 'rmdir\037%s\037\n' "$p" >> "$acts"
      else printf 'refuse\037%s\037%s\n' "$p" "directory not under ~/.local/share — left in place" >> "$acts"; fi
    else printf 'rmfile\037%s\037\n' "$p" >> "$acts"; fi
  done < "$cand"

  echo -e "  ${BOLD}Planned file actions:${RESET}"
  while IFS="$_LC_US" read -r act arg extra; do
    case "$act" in
      restore) echo "    restore  $arg  <- $extra"; n_restore=$((n_restore+1)) ;;
      rmfile)  echo "    remove   $arg"; n_rm=$((n_rm+1)) ;;
      rmdir)   echo "    remove   $arg/ (tool clone)"; n_rm=$((n_rm+1)) ;;
      gone)    echo "    skip     $arg (already gone)" ;;
      refuse)  echo -e "    ${YELLOW}REFUSED${RESET}  '$arg' — $extra"; n_skip=$((n_skip+1)) ;;
    esac
  done < "$acts"
  _LC_REFUSED=$n_skip

  _lc_collect_tools
  echo ""
  if [[ "$HTS_LC_PURGE" == "1" ]]; then
    echo -e "  ${BOLD}Tools to be removed (--purge-tools):${RESET}"
  else
    echo -e "  ${BOLD}Tools are NOT removed by default${RESET} (the manifest cannot prove you do not depend on them)."
    echo "  Commands to remove the recorded tools by hand (or re-run with --purge-tools):"
  fi
  _LC_MODE=print; _lc_tools_remove
  [[ -s "$_LC_TOOLS" ]] || echo "    (no tools recorded)"
  echo ""
  echo -e "  ${BOLD}Cannot be undone automatically:${RESET}"
  echo "    - Login shell change:        chsh -s <your previous shell>   (e.g. chsh -s /bin/bash)"
  echo "    - Homebrew itself:           /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
  echo "    - Oh My Zsh:                 uninstall_oh_my_zsh   (or remove ~/.oh-my-zsh yourself)"
  echo "    - Added package repos/taps:  brew untap <tap>; remove files in /etc/apt/sources.list.d, /etc/apt/keyrings, /etc/yum.repos.d"
  echo "    - npm prefix setting:        npm config delete prefix"
  echo ""
  _lc_confirm "Proceed with the uninstall described above?" || { rc=$?; _lc_cleanup; return $rc; }

  while IFS="$_LC_US" read -r act arg extra; do
    case "$act" in
      restore) _lc_restore_one "$arg" "$extra" || true ;;
      rmfile)  _lc_exec "remove $arg" rm -f -- "$arg" || true ;;
      rmdir)   _lc_exec "remove clone $arg" rm -rf -- "$arg" || true ;;
    esac
  done < "$acts"
  if [[ "$HTS_LC_PURGE" == "1" ]]; then
    _LC_MODE=exec; _lc_tools_remove
  fi
  _lc_summary || rc=1
  if [[ "$_LC_DRY" != "1" && "$rc" -eq 0 ]]; then
    local arch="$HTS_MANIFEST.uninstalled-$(date +%Y%m%d-%H%M%S)"
    if mv -- "$HTS_MANIFEST" "$arch"; then info "Manifest archived to $arch (backups kept in $HTS_BACKUP_ROOT)"
    else warn "could not archive manifest"; rc=1; fi
  elif [[ "$rc" -ne 0 ]]; then
    warn "Uninstall had failures — manifest kept so you can re-run."
  fi
  _lc_cleanup
  return $rc
}

# ─── --update ─────────────────────────────────────────────────────────────────
_lc_ver_gt() {   # a b -> 0 if a > b (numeric dotted compare)
  local a="${1#v}" b="${2#v}" i x y
  local -a A B
  a="${a%%[-+]*}"; b="${b%%[-+]*}"
  IFS=. read -r -a A <<< "$a"; IFS=. read -r -a B <<< "$b"
  for i in 0 1 2 3; do
    x="${A[$i]:-0}"; y="${B[$i]:-0}"
    case "$x$y" in *[!0-9]*) return 1 ;; esac
    [[ "$x" -gt "$y" ]] && return 0
    [[ "$x" -lt "$y" ]] && return 1
  done
  return 1
}
hts_lc_update() {
  _lc_init || return 1
  local tag out m names arr x mm name det mod rc=0
  step "Update"
  info "Installed version: ${HTS_VERSION:-unknown}"
  if [[ "$_LC_DRY" == "1" ]]; then
    echo -e "  ${DIM}[dry-run]${RESET} would query https://api.github.com/repos/$HTS_REPO_SLUG/releases/latest"
  elif command -v curl >/dev/null 2>&1 && \
       out="$(curl -fsS --max-time 5 -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$HTS_REPO_SLUG/releases/latest" 2>/dev/null)" && \
       tag="$(printf '%s' "$out" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)" && [[ -n "$tag" ]]; then
    if [[ -n "${HTS_VERSION:-}" ]] && _lc_ver_gt "$tag" "$HTS_VERSION"; then
      warn "A newer release is available: $tag (you have $HTS_VERSION)"
      echo "      Re-run the one-line install:  curl -fsSL https://raw.githubusercontent.com/$HTS_REPO_SLUG/main/ter.sh | bash -s -- <your usual flags>"
      echo "      or, in a clone:               git pull"
    else
      ok "Up to date (latest release: $tag)"
    fi
  else
    warn "Could not check for a newer release (network unavailable?) — continuing."
  fi

  _lc_collect_tools
  if [[ ! -s "$_LC_TOOLS" ]]; then info "No tools recorded in the manifest — nothing to upgrade."; _lc_cleanup; return 0; fi
  _LC_MODE=exec
  for m in brew pipx npm go apt dnf yum pacman zypper cargo; do
    names="$(_lc_names_for "$m")"; [[ -n "$names" ]] || continue
    read -r -a arr <<< "$names"
    case "$m" in
      brew) _lc_cmd "brew upgrade" brew upgrade "${arr[@]}" ;;
      npm)  _lc_cmd "npm -g update" npm -g update "${arr[@]}" ;;
      pipx) for x in "${arr[@]}"; do _lc_cmd "pipx upgrade $x" pipx upgrade "$x"; done ;;
      go)
        while IFS="$_LC_US" read -r mm name det; do
          [[ "$mm" == "go" ]] || continue
          mod="${det#go}"; mod="${mod#:}"; mod="${mod%@*}"
          if [[ -z "$mod" ]]; then info "go tool '$name': module path not recorded — skipped (newer installs record it)"; continue; fi
          if ! _lc_name_ok "$mod"; then warn "unsafe go module path for $name — skipped"; continue; fi
          _lc_cmd "go install $mod@latest" go install "$mod@latest"
        done < "$_LC_TOOLS" ;;
      apt|dnf|yum|pacman|zypper|cargo)
        info "$m tools (${arr[*]}) are left to the system package manager; upgrade them with your usual $m update." ;;
    esac
  done
  _lc_summary || rc=1
  _lc_cleanup
  return $rc
}

hts_lifecycle_run() {
  set +e
  local rc=0
  case "$HTS_LC_CMD" in
    status)    hts_lc_status    || rc=$? ;;
    restore)   hts_lc_restore   || rc=$? ;;
    uninstall) hts_lc_uninstall || rc=$? ;;
    update)    hts_lc_update    || rc=$? ;;
    *) err "unknown lifecycle command '$HTS_LC_CMD'"; rc=2 ;;
  esac
  return $rc
}
