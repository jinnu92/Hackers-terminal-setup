#!/usr/bin/env bash
# =============================================================================
#  lib/configs.sh — write_configs: ~/.zshrc and orchestration of all dotfiles
#  Related modules: configs_pentest.sh, configs_advanced.sh, configs_misc.sh,
#  dashboard.sh (welcome.zsh), hts_cli.sh (settings file + `hts` command)
# =============================================================================

write_configs() {
  step "Writing config files"

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$ZSH_CUSTOM"

  # Settings file (~/.config/hts/config, never overwritten) and the `hts` command first:
  # the generated files read the settings, and `hts` must exist wherever they are written.
  install_hts_cli || warn "hts command install had problems (see above)"

  # ─────────────────────────────────────────────────────────────────────────
  # ~/.zshrc  (prompt: exactly one of Powerlevel10k / Starship, chosen at shell start
  #            from the `prompt` setting; HTS_PROMPT only seeds the install-time default)
  # ─────────────────────────────────────────────────────────────────────────
  local PROMPT_CHOICE PROMPT_TOP PROMPT_TAIL
  PROMPT_CHOICE="$(hts_setting_get prompt)"
  read -r -d '' PROMPT_TOP << 'TOP_PROMPT' || true
# =============================================================================
# Prompt selection — setting `prompt` (p10k|starship) from ~/.config/hts/config
# Read line by line, never sourced. Change with: hts config prompt <p10k|starship>
# Exactly one of Powerlevel10k / Starship is activated; if the chosen one is not
# installed, the other is used with a one-line message.
# =============================================================================
_hts_prompt=__HTS_DEFAULT_PROMPT__
_hts_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/hts/config"
if [[ -r $_hts_cfg ]]; then
  while IFS= read -r _hts_l || [[ -n $_hts_l ]]; do
    case $_hts_l in
      prompt=p10k|prompt=starship) _hts_prompt=${_hts_l#prompt=} ;;
    esac
  done < "$_hts_cfg"
fi
_hts_have_starship() {
  local d
  for d in /opt/homebrew/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin "$HOME/.cargo/bin" "$HOME/.local/bin" $path; do
    [[ -x $d/starship ]] && return 0
  done
  return 1
}
if [[ $_hts_prompt == starship ]] && ! _hts_have_starship; then
  echo "hts: starship not found, using Powerlevel10k (hts config prompt p10k)" >&2
  _hts_prompt=p10k
elif [[ $_hts_prompt == p10k && ! -r "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme" ]] && _hts_have_starship; then
  echo "hts: Powerlevel10k not found, using Starship (hts config prompt starship)" >&2
  _hts_prompt=starship
fi
unset _hts_cfg _hts_l
unfunction _hts_have_starship
if [[ $_hts_prompt == p10k ]]; then
  # Powerlevel10k instant prompt — must stay above the Oh My Zsh section
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME=""
fi
TOP_PROMPT
  PROMPT_TOP="${PROMPT_TOP//__HTS_DEFAULT_PROMPT__/$PROMPT_CHOICE}"
  read -r -d '' PROMPT_TAIL << 'TAIL_PROMPT' || true
# =============================================================================
# Prompt activation (p10k config or Starship, per the `prompt` setting) — keep at the end
# =============================================================================
if [[ $_hts_prompt == starship ]]; then
  # Starship config: ~/.config/starship.toml
  if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
  else
    echo "hts: starship not found in PATH — run: hts config prompt p10k" >&2
  fi
else
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi
TAIL_PROMPT
  info "Prompt setting: $PROMPT_CHOICE (change any time with: hts config prompt p10k|starship)"

  log "Writing ~/.zshrc..."
  backup_file "$HOME/.zshrc"
  cat > "$HOME/.zshrc" << ZSHRC
${PROMPT_TOP}

# =============================================================================
# Oh My Zsh core (ZSH_THEME is set by the prompt selection above)
# =============================================================================
export ZSH="\$HOME/.oh-my-zsh"
# =============================================================================
# History — security-hardened
# =============================================================================
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE     # prefix with space → NOT saved to disk
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# =============================================================================
# Autosuggestions
# =============================================================================
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666,bold"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# =============================================================================
# zsh-completions fpath (before compinit)
# =============================================================================
fpath+=\${ZSH_CUSTOM:-\${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# =============================================================================
# Plugins — syntax-highlighting MUST be last
# =============================================================================
plugins=(
  git
  sudo
  history-substring-search
  colored-man-pages
  colorize
  extract
  command-not-found
  fzf
  zoxide
  z
  web-search
  python
  pip
  virtualenv
  node
  npm
  ssh-agent
  gpg-agent
  nmap
  eza
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# macOS-only plugins
[[ "\$(uname -s)" == "Darwin" ]] && plugins+=(macos)

source \$ZSH/oh-my-zsh.sh

# =============================================================================
# Universal PATH & Environment Setup
# =============================================================================
# 1. Homebrew (Apple Silicon / Intel / Linuxbrew)
if [[ -d "/opt/homebrew/bin" ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:\$PATH"
elif [[ -d "/usr/local/bin" ]]; then
  export PATH="/usr/local/bin:/usr/local/sbin:\$PATH"
elif [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:\$PATH"
fi

# 2. Local user binaries (pipx, yq, manual binaries)
export PATH="\$HOME/.local/bin:\$PATH"

# 3. Go language binaries
export GOPATH="\$HOME/go"
export PATH="\$HOME/go/bin:\$PATH"

# 4. Cargo / Rust & Astral uv binaries
export PATH="\$HOME/.cargo/bin:\$PATH"

# 5. Node.js & npm global prefix (Claude Code, promptfoo, MCP inspector)
export PATH="\$HOME/.npm-global/bin:\$PATH"
if command -v npm &>/dev/null; then
  _NPM_BIN="\$(npm config get prefix 2>/dev/null)/bin"
  [[ -n "\$_NPM_BIN" && -d "\$_NPM_BIN" && ":\$PATH:" != *":\$_NPM_BIN:"* ]] && export PATH="\$_NPM_BIN:\$PATH"
fi

# =============================================================================
# Ergonomics Hooks: Atuin, direnv
# =============================================================================
# Atuin shell history (local SQLite, secrets filtered; DB is not encrypted at rest)
command -v atuin &>/dev/null && eval "\$(atuin init zsh)"

# direnv (.envrc isolation)
command -v direnv &>/dev/null && eval "\$(direnv hook zsh)"

# =============================================================================
# Key bindings
# =============================================================================
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P'     history-substring-search-up
bindkey '^N'     history-substring-search-down
bindkey '^ '     autosuggest-accept

# =============================================================================
# bat & manpager
# =============================================================================
export BAT_THEME="TwoDark"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# =============================================================================
# fzf
# =============================================================================
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/.git/*"'
fi
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi --preview "bat --color=always --line-range :50 {}" --preview-window=right:50%:wrap'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -50'"

# =============================================================================
# zoxide
# =============================================================================
command -v zoxide &>/dev/null && eval "\$(zoxide init zsh)"

# =============================================================================
# Editor
# =============================================================================
export EDITOR="vim"
export VISUAL="vim"

${PROMPT_TAIL}

# =============================================================================
# hts: installer copy used by 'hts doctor|update|...' and 'doctor --full'
# =============================================================================
export HTS_TER_SH="\$HOME/.local/share/hts/ter.sh"

# =============================================================================
# Your own overrides — never created, modified or backed up by the installer
# =============================================================================
if [[ -f ~/.zshrc.local ]]; then
  source ~/.zshrc.local
fi
ZSHRC
  hts_track_file "$HOME/.zshrc"
  ok "~/.zshrc written"

  _hts_write_pentest_zsh
  _hts_write_advanced_pentest_zsh

  # ─────────────────────────────────────────────────────────────────────────
  # ~/.oh-my-zsh/custom/welcome.zsh (Tactical Security Cockpit, lib/dashboard.sh)
  # ─────────────────────────────────────────────────────────────────────────
  if command -v write_modern_welcome &>/dev/null; then
    write_modern_welcome
  fi

  _hts_write_tmux_conf
  _hts_make_workspace

  ok "All config files written"
}
