#!/usr/bin/env bash
# =============================================================================
#  lib/hts_cli.sh — Runtime settings file + the `hts` command
#    ~/.config/hts/config            user settings (never overwritten, never tracked)
#    ~/.local/bin/hts                the command (bash 3.2 compatible)
#    ~/.local/share/hts/ter.sh       installer copy that `hts doctor|update|...` runs
# =============================================================================

HTS_SETTING_KEYS="welcome welcome_ip tips prompt"

# hts_config_file — path of the settings file
hts_config_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/hts/config"
}

# hts_setting_default <key> — default value of a setting
hts_setting_default() {
  case "$1" in
    welcome)    echo "full" ;;
    welcome_ip) echo "show" ;;
    tips)       echo "on" ;;
    prompt)     _hts_prompt_choice ;;
  esac
}

# hts_setting_valid <key> <value> — succeed when value is allowed for key
hts_setting_valid() {
  case "$1=$2" in
    welcome=full|welcome=compact|welcome=off) return 0 ;;
    welcome_ip=show|welcome_ip=hide) return 0 ;;
    tips=on|tips=off) return 0 ;;
    prompt=p10k|prompt=starship) return 0 ;;
  esac
  return 1
}

# hts_setting_get <key> — effective value (last valid line wins, else default).
# Reads line by line; the file is never sourced or evaluated.
hts_setting_get() {
  local key=$1 file line val=""
  file="$(hts_config_file)"
  if [[ -r "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        "$key"=*) hts_setting_valid "$key" "${line#*=}" && val="${line#*=}" ;;
      esac
    done < "$file"
  fi
  [[ -n "$val" ]] || val="$(hts_setting_default "$key")"
  printf '%s\n' "$val"
}

# hts_settings_init — create the settings file with defaults on first install;
# on later runs only append keys that are missing. Existing values, comments and
# unknown lines are kept byte for byte. Never backed up, never tracked.
hts_settings_init() {
  local file dir key line found
  file="$(hts_config_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir" || { warn "Cannot create $dir"; return 1; }
  if [[ ! -f "$file" ]]; then
    {
      echo "# Hackers Terminal Setup settings — change with: hts config <key> <value>"
      echo "# Plain key=value lines; read at shell start, never executed."
      echo "# Allowed: welcome=full|compact|off  welcome_ip=show|hide  tips=on|off  prompt=p10k|starship"
    } > "$file" || { warn "Cannot write $file"; return 1; }
  fi
  for key in $HTS_SETTING_KEYS; do
    found=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in "$key"=*) found=1; break ;; esac
    done < "$file"
    [[ $found -eq 1 ]] || printf '%s=%s\n' "$key" "$(hts_setting_default "$key")" >> "$file"
  done
  return 0
}

# _hts_cli_script_source — print the installer file this run was started from,
# or nothing when the script arrived on stdin (curl | bash).
#   _HTS_PIPED and _HTS_ROOT are set by the bundle header at top level.
#   live-development mode (lib/ next to ter.sh): <root>/ter.sh
#   bundled single file: <root>/<name of the running script>
_hts_cli_script_source() {
  [[ "${_HTS_PIPED:-1}" == "0" && -n "${_HTS_ROOT:-}" ]] || return 1
  local cand
  if [[ -d "$_HTS_ROOT/lib" ]]; then
    cand="$_HTS_ROOT/ter.sh"
  else
    cand="$_HTS_ROOT/$(basename "$0")"
  fi
  [[ -f "$cand" && -s "$cand" ]] || return 1
  printf '%s\n' "$cand"
}

# _hts_cli_install_copy — place the installer copy at ~/.local/share/hts/ter.sh
_hts_cli_install_copy() {
  local share="$HOME/.local/share/hts" dest src tmp url
  dest="$share/ter.sh"
  mkdir -p "$share" || return 1
  if src="$(_hts_cli_script_source)"; then
    if [[ "$src" -ef "$dest" ]]; then
      :
    else
      tmp="$dest.part.$$"
      if cp "$src" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$dest"; then
        ok "Installer copy for 'hts' commands: $dest"
      else
        rm -f "$tmp"; warn "Could not copy the installer to $dest"; return 1
      fi
    fi
  else
    # Piped run: no file on disk. Reuse an existing copy of the same version.
    if [[ -f "$dest" ]] && grep -q "^HTS_VERSION=\"${HTS_VERSION}\"" "$dest" 2>/dev/null; then
      ok "Installer copy already present: $dest"
    else
      url="https://raw.githubusercontent.com/jinnu92/Hackers-terminal-setup/v${HTS_VERSION}/ter.sh"
      tmp="$dest.dl.$$"
      if hts_fetch "$url" "$tmp" && grep -q "^HTS_VERSION=" "$tmp" 2>/dev/null && chmod 755 "$tmp" && mv -f "$tmp" "$dest"; then
        ok "Installer copy for 'hts' commands downloaded: $dest"
      else
        rm -f "$tmp"
        warn "Could not download $url — 'hts doctor|update|...' will explain how to reinstall"
        return 1
      fi
    fi
  fi
  hts_track_file "$dest"
  return 0
}

# install_hts_cli — settings file, ~/.local/bin/hts and the installer copy. Idempotent
# (runs its work once per installer run; later calls return immediately).
install_hts_cli() {
  [[ "${_HTS_CLI_DONE:-0}" == "1" ]] && return 0
  _HTS_CLI_DONE=1
  local bin="$HOME/.local/bin/hts" body defprompt rc=0
  hts_settings_init || rc=1
  mkdir -p "$HOME/.local/bin" || return 1
  defprompt="$(_hts_prompt_choice)"
  body="$(_hts_cli_body)"
  body="${body//@@VERSION@@/$HTS_VERSION}"
  body="${body//@@DEFPROMPT@@/$defprompt}"
  backup_file "$bin"
  if printf '%s\n' "$body" > "$bin.part.$$" && chmod 755 "$bin.part.$$" && mv -f "$bin.part.$$" "$bin"; then
    hts_track_file "$bin"
    ok "hts command installed: $bin"
  else
    rm -f "$bin.part.$$"; warn "Could not write $bin"; return 1
  fi
  _hts_cli_install_copy || true
  return $rc
}

_hts_cli_body() {
  cat << 'HTS_CLI_SCRIPT'
#!/usr/bin/env bash
# hts — manage Hackers Terminal Setup (generated by the installer, v@@VERSION@@)
HTS_CLI_VERSION="@@VERSION@@"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/hts/config"
TER_SH="${HTS_TER_SH:-$HOME/.local/share/hts/ter.sh}"
KEYS="welcome welcome_ip tips prompt"
INSTALL_CMD="curl -fsSL https://raw.githubusercontent.com/jinnu92/Hackers-terminal-setup/main/ter.sh | bash"

allowed() {
  case "$1" in
    welcome)    echo "full compact off" ;;
    welcome_ip) echo "show hide" ;;
    tips)       echo "on off" ;;
    prompt)     echo "p10k starship" ;;
    *) return 1 ;;
  esac
}
default_of() {
  case "$1" in
    welcome) echo full ;; welcome_ip) echo show ;; tips) echo on ;; prompt) echo "@@DEFPROMPT@@" ;;
  esac
}
describe() {
  case "$1" in
    welcome)    echo "welcome screen in each new tab: full box, compact (1-2 lines) or off" ;;
    welcome_ip) echo "hide masks IP addresses in the welcome screen" ;;
    tips)       echo "rotating tip in the welcome screen" ;;
    prompt)     echo "shell prompt: Powerlevel10k or Starship" ;;
  esac
}
valid() { # key value
  local v
  for v in $(allowed "$1"); do [ "$v" = "$2" ] && return 0; done
  return 1
}
# value of a key: last valid line wins, else default. The file is only read, never executed.
current() {
  local key=$1 val="" line
  if [ -r "$CFG" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in "$key"=*) valid "$key" "${line#*=}" && val="${line#*=}" ;; esac
    done < "$CFG"
  fi
  [ -n "$val" ] || val="$(default_of "$key")"
  printf '%s\n' "$val"
}
write_defaults() {
  local k
  mkdir -p "$(dirname "$CFG")" || return 1
  {
    echo "# Hackers Terminal Setup settings — change with: hts config <key> <value>"
    echo "# Plain key=value lines; read at shell start, never executed."
    echo "# Allowed: welcome=full|compact|off  welcome_ip=show|hide  tips=on|off  prompt=p10k|starship"
    for k in $KEYS; do printf '%s=%s\n' "$k" "$(default_of "$k")"; done
  } > "$CFG"
}
set_value() { # key value — replace the line (keep everything else), append if missing
  local key=$1 val=$2 line done_=0 tmp
  [ -f "$CFG" ] || write_defaults || return 1
  tmp="$CFG.tmp.$$"
  : > "$tmp" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$key"=*) if [ $done_ -eq 0 ]; then printf '%s=%s\n' "$key" "$val" >> "$tmp"; done_=1; fi ;;
      *) printf '%s\n' "$line" >> "$tmp" ;;
    esac
  done < "$CFG"
  [ $done_ -eq 1 ] || printf '%s=%s\n' "$key" "$val" >> "$tmp"
  mv -f "$tmp" "$CFG"
}
when_applies() {
  echo "Takes effect in the next terminal tab (or run: exec zsh). No reinstall needed."
}
bad_key() {
  echo "hts: unknown setting '$1'. Valid settings: $KEYS" >&2
  exit 2
}
bad_value() {
  echo "hts: invalid value '$2' for '$1'. Allowed: $(allowed "$1")" >&2
  exit 2
}

cmd_config() {
  local key val k
  case "${1:-}" in
    "")
      echo "Settings file: $CFG"
      for k in $KEYS; do
        printf '  %-11s = %-9s allowed: %-17s default: %s\n' "$k" "$(current "$k")" "$(allowed "$k" | tr ' ' '|')" "$(default_of "$k")"
        printf '  %-11s   %s\n' "" "$(describe "$k")"
      done
      echo
      echo "Change:  hts config <key> <value>     Reset: hts config reset"
      echo "Anything else: put it in ~/.zshrc.local (sourced last; the installer never touches it)."
      ;;
    reset)
      write_defaults || { echo "hts: cannot write $CFG" >&2; exit 1; }
      echo "Settings reset to defaults in $CFG"
      when_applies
      ;;
    *)
      key=$1
      allowed "$key" >/dev/null || bad_key "$key"
      if [ $# -eq 1 ]; then current "$key"; return 0; fi
      [ $# -le 2 ] || { echo "hts: too many arguments. Usage: hts config <key> <value>" >&2; exit 2; }
      val=$2
      valid "$key" "$val" || bad_value "$key" "$val"
      set_value "$key" "$val" || { echo "hts: cannot write $CFG" >&2; exit 1; }
      echo "$key = $val"
      when_applies
      ;;
  esac
}

delegate() { # installer-flag [args...]
  if [ ! -f "$TER_SH" ]; then
    echo "hts: the installer copy was not found at $TER_SH" >&2
    echo "Reinstall to restore it:" >&2
    echo "  $INSTALL_CMD" >&2
    exit 1
  fi
  exec bash "$TER_SH" "$@"
}

usage() {
  cat << EOF
hts $HTS_CLI_VERSION — Hackers Terminal Setup

Usage: hts <command> [args]

Settings (take effect in the next terminal tab, no reinstall):
  hts config                   Show current settings and allowed values
  hts config <key> <value>     Change one setting
  hts config reset             Restore defaults
    welcome     full | compact | off     welcome screen (default full)
    welcome_ip  show | hide              mask IP addresses in it (default show)
    tips        on | off                 rotating tip (default on)
    prompt      p10k | starship          shell prompt (default: install-time HTS_PROMPT, else p10k)

Installer commands (run the installed copy of ter.sh):
  hts doctor                   Audit the environment          (ter.sh --doctor)
  hts status                   Show installed components      (--status)
  hts update                   Check for a newer release      (--update)
  hts uninstall                Restore backups / remove files (--uninstall)
  hts restore [TS]             Restore backed-up files        (--restore)
  hts list                     List components                (--list)
  hts version                  Print the version              (--version)
  hts dry-run <options>        Preview an install             (--dry-run ...)
  hts help                     This help

Files:
  Settings        $CFG
  Your overrides  ~/.zshrc.local (sourced last; never touched by the installer)
  Installer copy  $TER_SH
Uninstalling leaves the settings file in place (it is your data); delete it with:
  rm -r "$(dirname "$CFG")"
EOF
}

case "${1:-}" in
  "")                usage ;;
  help|-h|--help)    usage ;;
  config)            shift; cmd_config "$@" ;;
  doctor)            shift; delegate --doctor "$@" ;;
  status)            shift; delegate --status "$@" ;;
  update)            shift; delegate --update "$@" ;;
  uninstall)         shift; delegate --uninstall "$@" ;;
  restore)           shift; delegate --restore "$@" ;;
  list)              shift; delegate --list "$@" ;;
  dry-run)           shift; delegate --dry-run "$@" ;;
  version|-V|--version)
    if [ -f "$TER_SH" ]; then exec bash "$TER_SH" --version; fi
    echo "hts $HTS_CLI_VERSION (installer copy not found at $TER_SH)" ;;
  *) echo "hts: unknown command '$1'. Run 'hts help'." >&2; exit 2 ;;
esac
HTS_CLI_SCRIPT
}
