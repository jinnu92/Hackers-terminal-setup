#!/usr/bin/env bash
# =============================================================================
#  lib/terminals.sh — GPU Terminal Emulators & Aesthetic Configs
#  Supports: Ghostty, WezTerm, Kitty, Alacritty
#
#  Install matrix (what this module actually installs):
#    terminal   macOS(cask)  apt                       dnf                 pacman
#    Ghostty    yes          skip (no official pkg)    skip (no official)  yes
#    WezTerm    yes          yes (upstream apt repo)   yes (upstream COPR) yes
#    Kitty      yes          yes                       yes                 yes
#    Alacritty  yes          yes if the release has it yes                 yes
#  zypper: Kitty and Alacritty only. yum and others: nothing installed.
#  WSL and headless Linux (no DISPLAY/WAYLAND_DISPLAY): no GUI installs at all.
#  A terminal's config file is written only when that terminal is installed.
# =============================================================================

_term_is_wsl() {
  [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null
}

# _term_gui_ok — succeeds when GUI terminals make sense here; warns otherwise
_term_gui_ok() {
  [[ "$OS" == "Darwin" ]] && return 0
  if _term_is_wsl; then
    warn "WSL detected — skipping GUI terminal installs (use Windows Terminal or install terminals on the Windows side)"
    return 1
  fi
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    warn "Headless Linux (no DISPLAY/WAYLAND_DISPLAY) — skipping GUI terminal installs"
    return 1
  fi
  return 0
}

# _term_present <command> <MacApp.app>
_term_present() {
  command -v "$1" &>/dev/null || [[ -d "/Applications/$2" ]]
}

# _term_linux_install <package> — install via the distro package manager
_term_linux_install() {
  local pkg=$1 rc=1
  case "$PKG_MGR" in
    apt)    sudo apt-get install -y "$pkg" && rc=0 ;;
    dnf)    sudo dnf install -y "$pkg" && rc=0 ;;
    pacman) sudo pacman -S --noconfirm --needed "$pkg" && rc=0 ;;
    zypper) sudo zypper install -y "$pkg" && rc=0 ;;
  esac
  if [[ $rc -eq 0 ]]; then
    hts_manifest_add tool "$pkg" "$PKG_MGR"
  else
    warn "$PKG_MGR install $pkg failed"
  fi
  return $rc
}

install_ghostty() {
  step "Ghostty Terminal Emulator"
  if ! _term_present ghostty Ghostty.app; then
    _term_gui_ok || return 0
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask ghostty
    else
      case "$PKG_MGR" in
        pacman) _term_linux_install ghostty || return 1 ;;
        *) warn "Ghostty: skipped on $PKG_MGR — no official package (only community repos); see https://ghostty.org/docs/install/binary-preview"
           return 0 ;;
      esac
    fi
  else
    ok "Ghostty already installed"
  fi
  if _term_present ghostty Ghostty.app; then write_ghostty_config; fi
  return 0
}

install_wezterm() {
  step "WezTerm Terminal Emulator"
  if ! _term_present wezterm WezTerm.app; then
    _term_gui_ok || return 0
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask wezterm
    else
      case "$PKG_MGR" in
        pacman) _term_linux_install wezterm || return 1 ;;
        dnf)
          warn "WezTerm has no Fedora package — enabling upstream COPR wezfurlong/wezterm-nightly (nightly builds by the WezTerm author)"
          if sudo dnf copr enable -y wezfurlong/wezterm-nightly && sudo dnf install -y wezterm; then
            hts_manifest_add tool wezterm "dnf (copr wezfurlong/wezterm-nightly)"
          else
            warn "dnf install wezterm failed"; return 1
          fi ;;
        apt)
          warn "WezTerm has no Debian/Ubuntu package — adding upstream apt repository https://apt.fury.io/wez/ (maintained by the WezTerm author)"
          local keytmp
          keytmp="$(mktemp "${TMPDIR:-/tmp}/wezkey.XXXXXX")" || return 1
          if hts_fetch "https://apt.fury.io/wez/gpg.key" "$keytmp" && \
             sudo mkdir -p /etc/apt/keyrings && \
             sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm.gpg "$keytmp"; then
            echo 'deb [signed-by=/etc/apt/keyrings/wezterm.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
            if sudo apt-get update -qq && sudo apt-get install -y wezterm; then
              hts_manifest_add tool wezterm "apt (apt.fury.io/wez)"
            else
              warn "apt install wezterm failed"; rm -f "$keytmp"; return 1
            fi
          else
            warn "Could not fetch/install the WezTerm apt signing key — skipping WezTerm"
            rm -f "$keytmp"; return 1
          fi
          rm -f "$keytmp" ;;
        *) warn "WezTerm: skipped on $PKG_MGR — no package; see https://wezfurlong.org/wezterm/install/linux.html"
           return 0 ;;
      esac
    fi
  else
    ok "WezTerm already installed"
  fi
  if _term_present wezterm WezTerm.app; then write_wezterm_config; fi
  return 0
}

install_kitty() {
  step "Kitty Terminal Emulator"
  if ! _term_present kitty kitty.app; then
    _term_gui_ok || return 0
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask kitty
    else
      case "$PKG_MGR" in
        apt|dnf|pacman|zypper) _term_linux_install kitty || return 1 ;;
        *) warn "Kitty: skipped on $PKG_MGR — no distro package (the upstream curl installer is deliberately not used)"
           return 0 ;;
      esac
    fi
  else
    ok "Kitty already installed"
  fi
  if _term_present kitty kitty.app; then write_kitty_config; fi
  return 0
}

install_alacritty() {
  step "Alacritty Terminal Emulator"
  if ! _term_present alacritty Alacritty.app; then
    _term_gui_ok || return 0
    if [[ "$OS" == "Darwin" ]]; then
      if ! pkg_install_cask alacritty || ! _term_present alacritty Alacritty.app; then
        warn "Alacritty: skipped — the Homebrew cask is unavailable (Homebrew disables casks that fail macOS Gatekeeper checks)"
        hts_result skip "Alacritty" "Homebrew cask unavailable"
        return 0
      fi
    else
      case "$PKG_MGR" in
        apt)
          if apt-cache show alacritty >/dev/null 2>&1; then
            _term_linux_install alacritty || return 1
          else
            warn "Alacritty: skipped — not in this release's apt repositories (needs Debian 13+/Ubuntu 24.04+ or cargo install)"
            return 0
          fi ;;
        dnf|pacman|zypper) _term_linux_install alacritty || return 1 ;;
        *) warn "Alacritty: skipped on $PKG_MGR — no package mapping"
           return 0 ;;
      esac
    fi
  else
    ok "Alacritty already installed"
  fi
  if _term_present alacritty Alacritty.app; then write_alacritty_config; fi
  return 0
}

write_ghostty_config() {
  local cfg_dir="$HOME/.config/ghostty"
  mkdir -p "$cfg_dir/themes"

  # Write fallback catppuccin-mocha theme file so both casing styles work seamlessly
  backup_file "$cfg_dir/themes/catppuccin-mocha"
  cat > "$cfg_dir/themes/catppuccin-mocha" << 'MOCHA_THEME'
# Catppuccin Mocha palette — https://github.com/catppuccin/ghostty
# MIT License, Copyright (c) 2021 Catppuccin
palette = 0=#45475a
palette = 1=#f38ba8
palette = 2=#a6e3a1
palette = 3=#f9e2af
palette = 4=#89b4fa
palette = 5=#f5c2e7
palette = 6=#94e2d5
palette = 7=#a6adc8
palette = 8=#585b70
palette = 9=#f37799
palette = 10=#89d88b
palette = 11=#ebd391
palette = 12=#74a8fc
palette = 13=#f2aede
palette = 14=#6bd7ca
palette = 15=#bac2de
background = #1e1e2e
foreground = #cdd6f4
cursor-color = #f5e0dc
cursor-text = #1e1e2e
selection-background = #585b70
selection-foreground = #cdd6f4
MOCHA_THEME
  hts_track_file "$cfg_dir/themes/catppuccin-mocha"

  log "Writing Ghostty aesthetic configuration ($cfg_dir/config)..."
  backup_file "$cfg_dir/config"
  cat > "$cfg_dir/config" << 'GHOSTTY_CFG'
# =============================================================================
# Ghostty Terminal Configuration — Catppuccin Mocha & Hacker Ergonomics
# =============================================================================
theme = "Catppuccin Mocha"
font-family = "JetBrainsMono Nerd Font"
font-family = "MesloLGS NF"
font-size = 14
font-feature = ["calt", "liga", "dlig"]

# Window & Vibrancy
window-padding-x = 12
window-padding-y = 10
macos-titlebar-style = "transparent"
background-opacity = 0.94
background-blur-radius = 24
cursor-style = "block"
cursor-style-blink = true
mouse-hide-while-typing = true

# Splits & Keybindings
keybind = super+t=new_tab
keybind = super+w=close_surface
keybind = super+d=new_split:right
keybind = super+shift+d=new_split:down
keybind = super+h=goto_split:left
keybind = super+j=goto_split:down
keybind = super+k=goto_split:up
keybind = super+l=goto_split:right
keybind = super+plus=increase_font_size:1
keybind = super+minus=decrease_font_size:1
keybind = super+zero=reset_font_size
GHOSTTY_CFG
  hts_track_file "$cfg_dir/config"
  ok "Ghostty configuration deployed"
}

write_wezterm_config() {
  local cfg_dir="$HOME/.config/wezterm"
  mkdir -p "$cfg_dir"
  log "Writing WezTerm configuration ($cfg_dir/wezterm.lua)..."
  backup_file "$cfg_dir/wezterm.lua"
  cat > "$cfg_dir/wezterm.lua" << 'WEZTERM_CFG'
-- =============================================================================
-- WezTerm Configuration — Cross-Platform Lua Multiplexer
-- =============================================================================
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha'
config.font = wezterm.font_with_fallback({
  'JetBrainsMono Nerd Font',
  'MesloLGS NF',
  'FiraCode Nerd Font',
})
config.font_size = 13.5
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

config.window_background_opacity = 0.94
config.macos_window_background_blur = 20
config.window_padding = {
  left = 12,
  right = 12,
  top = 10,
  bottom = 10,
}

config.enable_tab_bar = true
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false

config.keys = {
  { key = 'd', mods = 'CMD', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'CMD|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Down' },
}

return config
WEZTERM_CFG
  hts_track_file "$cfg_dir/wezterm.lua"
  ok "WezTerm configuration deployed"
}

write_kitty_config() {
  local cfg_dir="$HOME/.config/kitty"
  mkdir -p "$cfg_dir"
  log "Writing Kitty configuration ($cfg_dir/kitty.conf)..."
  backup_file "$cfg_dir/kitty.conf"
  cat > "$cfg_dir/kitty.conf" << 'KITTY_CFG'
# =============================================================================
# Kitty Terminal Configuration — Catppuccin Mocha
# =============================================================================
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
font_size        13.5
enable_audio_bell no
background_opacity 0.94
background_blur 20
window_padding_width 10

# Catppuccin Mocha Theme Colors
background            #1e1e2e
foreground            #cdd6f4
selection_background  #f5e0dc
selection_foreground  #1e1e2e
cursor                #f5e0dc
cursor_text_color     #1e1e2e
active_tab_foreground   #11111b
active_tab_background   #cba6f7
inactive_tab_foreground #cdd6f4
inactive_tab_background #181825

# Keybindings
map cmd+t new_tab
map cmd+w close_tab
map cmd+d launch --location=vsplit --cwd=current
map cmd+shift+d launch --location=hsplit --cwd=current
KITTY_CFG
  hts_track_file "$cfg_dir/kitty.conf"
  ok "Kitty configuration deployed"
}

write_alacritty_config() {
  local cfg_dir="$HOME/.config/alacritty"
  mkdir -p "$cfg_dir"
  log "Writing Alacritty configuration ($cfg_dir/alacritty.toml)..."
  backup_file "$cfg_dir/alacritty.toml"
  cat > "$cfg_dir/alacritty.toml" << 'ALACRITTY_CFG'
# =============================================================================
# Alacritty Configuration — Catppuccin Mocha
# =============================================================================
[window]
padding = { x = 12, y = 10 }
opacity = 0.94
blur = true
decorations = "Buttonless"

[font]
size = 13.5
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.normal]
black   = "#45475a"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#bac2de"
ALACRITTY_CFG
  hts_track_file "$cfg_dir/alacritty.toml"
  ok "Alacritty configuration deployed"
}

install_terminals() {
  step "GPU-Accelerated Modern Terminal Emulators"
  info "Terminals: Ghostty, WezTerm, Kitty, Alacritty (installed only where a reliable package exists)"
  local failed=0
  install_ghostty   || failed=1
  install_wezterm   || failed=1
  install_kitty     || failed=1
  install_alacritty || failed=1
  if [[ $failed -eq 1 ]]; then
    warn "One or more terminal installs failed (see messages above)"
    return 1
  fi
  ok "Terminal step complete (configs written only for installed terminals)"
  return 0
}
