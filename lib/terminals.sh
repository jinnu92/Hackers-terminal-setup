#!/usr/bin/env bash
# =============================================================================
#  lib/terminals.sh — Modern GPU Terminal Emulators & Aesthetic Configs
#  Supports: Ghostty (recommended macOS/Wayland), WezTerm, Kitty, Alacritty
# =============================================================================

install_ghostty() {
  step "Ghostty Terminal Emulator"
  if command -v ghostty &>/dev/null || [[ -d "/Applications/Ghostty.app" ]]; then
    ok "Ghostty already installed"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask ghostty
    else
      # Linux installation
      case "$PKG_MGR" in
        pacman) sudo pacman -S --noconfirm --needed ghostty || warn "pacman install ghostty failed" ;;
        dnf)    sudo dnf copr enable -y pgdev/ghostty 2>/dev/null && sudo dnf install -y ghostty || warn "dnf install ghostty failed" ;;
        apt)
          log "Ghostty on Debian/Ubuntu: checking for snap/flatpak..."
          if command -v flatpak &>/dev/null; then
            flatpak install -y flathub com.mitchellh.ghostty 2>/dev/null || warn "flatpak install ghostty failed"
          elif command -v snap &>/dev/null; then
            sudo snap install ghostty --classic 2>/dev/null || warn "snap install ghostty failed"
          else
            warn "Ghostty: install via Flatpak (com.mitchellh.ghostty) or download from ghostty.org"
          fi
          ;;
        *) warn "Ghostty: see https://ghostty.org for your Linux distribution package" ;;
      esac
    fi
  fi
  write_ghostty_config
}

install_wezterm() {
  step "WezTerm Terminal Emulator"
  if command -v wezterm &>/dev/null || [[ -d "/Applications/WezTerm.app" ]]; then
    ok "WezTerm already installed"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask wezterm
    else
      case "$PKG_MGR" in
        pacman) sudo pacman -S --noconfirm --needed wezterm || warn "pacman install wezterm failed" ;;
        dnf)    sudo dnf copr enable -y wezfurlong/wezterm-nightly 2>/dev/null && sudo dnf install -y wezterm || warn "dnf install wezterm failed" ;;
        apt)
          log "Setting up WezTerm apt repository..."
          curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm.gpg 2>/dev/null || true
          echo 'deb [signed-by=/etc/apt/keyrings/wezterm.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
          sudo apt-get update -qq && sudo apt-get install -y wezterm || warn "apt install wezterm failed"
          ;;
        *) warn "WezTerm: download from wezfurlong.org/wezterm" ;;
      esac
    fi
  fi
  write_wezterm_config
}

install_kitty() {
  step "Kitty Terminal Emulator"
  if command -v kitty &>/dev/null || [[ -d "/Applications/kitty.app" ]]; then
    ok "Kitty already installed"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask kitty
    else
      case "$PKG_MGR" in
        apt)    sudo apt-get install -y kitty || warn "apt install kitty failed" ;;
        dnf)    sudo dnf install -y kitty || warn "dnf install kitty failed" ;;
        pacman) sudo pacman -S --noconfirm --needed kitty || warn "pacman install kitty failed" ;;
        *)      curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin || warn "kitty installer script failed" ;;
      esac
    fi
  fi
  write_kitty_config
}

install_alacritty() {
  step "Alacritty Terminal Emulator"
  if command -v alacritty &>/dev/null || [[ -d "/Applications/Alacritty.app" ]]; then
    ok "Alacritty already installed"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask alacritty
    else
      pkg_install alacritty
    fi
  fi
  write_alacritty_config
}

write_ghostty_config() {
  local cfg_dir="$HOME/.config/ghostty"
  mkdir -p "$cfg_dir/themes"

  # Write fallback catppuccin-mocha theme file so both casing styles work seamlessly
  cat > "$cfg_dir/themes/catppuccin-mocha" << 'MOCHA_THEME'
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

  log "Writing Ghostty aesthetic configuration ($cfg_dir/config)..."
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
  ok "Ghostty configuration deployed"
}

write_wezterm_config() {
  local cfg_dir="$HOME/.config/wezterm"
  mkdir -p "$cfg_dir"
  log "Writing WezTerm configuration ($cfg_dir/wezterm.lua)..."
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
  ok "WezTerm configuration deployed"
}

write_kitty_config() {
  local cfg_dir="$HOME/.config/kitty"
  mkdir -p "$cfg_dir"
  log "Writing Kitty configuration ($cfg_dir/kitty.conf)..."
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
  ok "Kitty configuration deployed"
}

write_alacritty_config() {
  local cfg_dir="$HOME/.config/alacritty"
  mkdir -p "$cfg_dir"
  log "Writing Alacritty configuration ($cfg_dir/alacritty.toml)..."
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
  ok "Alacritty configuration deployed"
}

install_terminals() {
  step "GPU-Accelerated Modern Terminal Emulators"
  echo ""
  info "Available GPU terminals: Ghostty (recommended for macOS), WezTerm, Kitty, Alacritty"
  
  if [[ "$OS" == "Darwin" ]]; then
    # Default to Ghostty and WezTerm on macOS
    install_ghostty
    write_wezterm_config
    write_kitty_config
    write_alacritty_config
  else
    # Linux: deploy configs and install available
    write_ghostty_config
    write_wezterm_config
    write_kitty_config
    write_alacritty_config
    if command -v pacman &>/dev/null; then
      install_ghostty
      install_wezterm
    else
      install_kitty
    fi
  fi
  ok "GPU Terminal configurations installed to ~/.config/"
}
