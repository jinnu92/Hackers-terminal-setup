#!/usr/bin/env bash
# =============================================================================
#  lib/configs_misc.sh — Generates ~/.tmux.conf and the ~/pentest + ~/workspace directories
# =============================================================================

_hts_write_tmux_conf() {
  log "Writing ~/.tmux.conf..."
  backup_file "$HOME/.tmux.conf"
  cat > "$HOME/.tmux.conf" << 'TMUXCONF'
# =============================================================================
# tmux config — security terminal (macOS + Linux)
# =============================================================================
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Prefix: Ctrl+A
unbind C-b
set -g prefix C-a
bind-key C-a send-prefix

# Splits
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# Vim-style pane nav
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Reload
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# True color
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Status bar
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[bg=#89b4fa,fg=#1e1e2e,bold] 󰖳 #S #[default] "
set -g status-right "#[fg=#a6e3a1] #{pane_current_path} #[fg=#f38ba8] #(hostname -I 2>/dev/null | awk '{print $1}' || ipconfig getifaddr en0 2>/dev/null) #[fg=#cdd6f4] %H:%M "
set -g status-left-length 30
set -g status-right-length 90
setw -g window-status-current-style "fg=#89b4fa,bold"
setw -g window-status-current-format " #I:#W "
setw -g window-status-format " #I:#W "
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#89b4fa"
set -sg escape-time 10
setw -g monitor-activity on
set -g visual-activity off
TMUXCONF
  hts_track_file "$HOME/.tmux.conf"
  ok "~/.tmux.conf written"
}

_hts_make_workspace() {
  # ─── Workspace ────────────────────────────────────────────────────────────
  mkdir -p "$HOME/pentest/"{bb,cloud,ai_sec,mcp_sec,reports,tools,wordlists}
  mkdir -p "$HOME/workspace"
  if [[ -d "$HOME/pentest/wordlists/seclists" ]]; then
    ok "SecLists found in $HOME/pentest/wordlists/seclists"
  elif [[ -d /opt/seclists ]]; then
    ln -sf /opt/seclists "$HOME/pentest/wordlists/seclists" 2>/dev/null || true
  elif [[ -d /usr/share/seclists ]]; then
    ln -sf /usr/share/seclists "$HOME/pentest/wordlists/seclists" 2>/dev/null || true
  fi
  ok "~/pentest/ & ~/workspace/ directories ready"
}
