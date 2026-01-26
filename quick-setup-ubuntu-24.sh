#!/usr/bin/env bash
set -u
set -o pipefail

# Quick setup for Ubuntu 24.04 (WSL-friendly)

TARGET_TIMEZONE="${TARGET_TIMEZONE:-Asia/Taipei}"
SET_TIMEZONE="${SET_TIMEZONE:-1}"
INSTALL_CORE_PACKAGES="${INSTALL_CORE_PACKAGES:-1}"
INSTALL_BETTER_RM="${INSTALL_BETTER_RM:-1}"
INSTALL_RUST="${INSTALL_RUST:-0}"
INSTALL_YAZI="${INSTALL_YAZI:-0}"
INSTALL_NODE="${INSTALL_NODE:-1}"
NODE_VERSION="${NODE_VERSION:-22}"
INSTALL_STARSHIP="${INSTALL_STARSHIP:-1}"
INSTALL_FZF="${INSTALL_FZF:-1}"
RUN_GIT_SETUP="${RUN_GIT_SETUP:-0}"
CONFIG_GIT_GCM_WSL="${CONFIG_GIT_GCM_WSL:-1}"
CONFIG_AZURE_DEVOPS_GIT="${CONFIG_AZURE_DEVOPS_GIT:-0}"
INSTALL_GH="${INSTALL_GH:-1}"
INSTALL_COPILOT="${INSTALL_COPILOT:-1}"
INSTALL_AICHAT="${INSTALL_AICHAT:-0}"
AICHAT_SYNC_MODELS="${AICHAT_SYNC_MODELS:-0}"
INSTALL_UV="${INSTALL_UV:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-0}"
INSTALL_GEMINI="${INSTALL_GEMINI:-0}"
INSTALL_CLAUDE="${INSTALL_CLAUDE:-0}"
INSTALL_SUPERCLAUDE="${INSTALL_SUPERCLAUDE:-0}"
INSTALL_AZURE_CLI="${INSTALL_AZURE_CLI:-0}"
INSTALL_GCLOUD="${INSTALL_GCLOUD:-0}"
ENABLE_WSL_LOCAL_VAR="${ENABLE_WSL_LOCAL_VAR:-1}"

GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

LOG_FILE="${LOG_FILE:-$HOME/quick-setup-ubuntu-24.log}"

if [ -t 1 ]; then
  BOLD=$'\033[1m'
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  MAGENTA=$'\033[0;35m'
  CYAN=$'\033[0;36m'
  RESET=$'\033[0m'
else
  BOLD=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
  RESET=""
fi

log_step() { printf "%b\n" "${BOLD}${MAGENTA}==>${RESET} $*"; }
log_info() { printf "%b\n" "${CYAN}INFO${RESET} $*"; }
log_warn() { printf "%b\n" "${YELLOW}WARN${RESET} $*"; }
log_error() { printf "%b\n" "${RED}ERROR${RESET} $*"; }
log_success() { printf "%b\n" "${GREEN}OK${RESET} $*"; }
log_skip() { printf "%b\n" "${YELLOW}SKIP${RESET} $*"; }
log_tip() { printf "%b\n" "${BLUE}TIP${RESET} $*"; }

errors=()
manual_actions=()

is_enabled() { [ "${1:-0}" = "1" ]; }
add_error() { errors+=("$1"); }
add_manual() { manual_actions+=("$1"); }

run_cmd() {
  local desc="$1"
  shift
  log_step "$desc"
  if "$@"; then
    log_success "$desc"
    return 0
  fi
  local rc=$?
  log_error "$desc failed (exit $rc)."
  add_error "$desc (exit $rc)"
  return $rc
}

append_block() {
  local file="$1"
  local marker="$2"
  local block="$3"

  if [ ! -f "$file" ]; then
    if ! touch "$file"; then
      log_error "Unable to write $file."
      add_error "Unable to write $file"
      return 1
    fi
  fi

  if grep -qF "$marker" "$file"; then
    log_info "Config already present in $file ($marker)."
    return 0
  fi

  printf "\n%s\n" "$block" >> "$file"
  log_success "Updated $file."
}

get_current_timezone() {
  local tz=""
  if command -v timedatectl >/dev/null 2>&1; then
    tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  fi
  if [ -z "$tz" ] && [ -f /etc/timezone ]; then
    tz=$(cat /etc/timezone 2>/dev/null || true)
  fi
  if [ -z "$tz" ] && [ -L /etc/localtime ]; then
    tz=$(readlink -f /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
  fi
  printf "%s" "$tz"
}

get_latest_github_tag() {
  local repo="$1"
  if command -v jq >/dev/null 2>&1; then
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name
  else
    curl -s "https://api.github.com/repos/${repo}/releases/latest" \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
  fi
}

if ! touch "$LOG_FILE" 2>/dev/null; then
  printf "ERROR: cannot write log file: %s\n" "$LOG_FILE" >&2
  exit 1
fi
exec > >(tee -a "$LOG_FILE") 2>&1

log_info "Starting quick setup for Ubuntu 24.04. You got this! :)"
log_info "Log file: $LOG_FILE"

log_step "Preflight: OS check"
if [ ! -r /etc/os-release ]; then
  log_error "Missing /etc/os-release. Cannot verify OS."
  exit 1
fi
set +u
. /etc/os-release
set -u
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  log_error "This script supports Ubuntu 24.04 only."
  log_error "Detected: ID=${ID:-unknown}, VERSION_ID=${VERSION_ID:-unknown}"
  exit 1
fi
log_success "Ubuntu 24.04 detected."

IS_WSL=0
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  IS_WSL=1
fi
if [ -n "${WSL_INTEROP:-}" ] || [ -n "${WSL_DISTRO_NAME:-}" ]; then
  IS_WSL=1
fi
if [ "$IS_WSL" -eq 1 ]; then
  log_success "WSL detected."
else
  log_warn "WSL not detected. WSL-only steps will be skipped."
fi

log_step "Checking sudo access"
if sudo -v; then
  log_success "Sudo is ready."
else
  log_error "Sudo access is required."
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

log_step "Ensure ~/.local/bin exists"
if [ -d "$HOME/.local/bin" ]; then
  log_success "~/.local/bin already exists."
else
  if mkdir -p "$HOME/.local/bin"; then
    log_success "Created ~/.local/bin."
  else
    log_error "Failed to create ~/.local/bin."
    add_error "mkdir ~/.local/bin failed"
  fi
fi

if is_enabled "$INSTALL_CORE_PACKAGES"; then
  run_cmd "apt update" sudo apt-get update
  run_cmd "apt upgrade -y" sudo apt-get upgrade -y
else
  log_skip "Core package install disabled (INSTALL_CORE_PACKAGES=0)."
fi

current_tz=$(get_current_timezone)
if [ -n "$current_tz" ]; then
  log_info "Current timezone: $current_tz"
else
  log_warn "Unable to detect current timezone."
fi

if is_enabled "$SET_TIMEZONE"; then
  if [ -z "$TARGET_TIMEZONE" ]; then
    log_warn "TARGET_TIMEZONE is empty; skipping timezone change."
  elif [ "$current_tz" = "$TARGET_TIMEZONE" ]; then
    log_success "Timezone already set to $TARGET_TIMEZONE."
  else
    log_step "Setting timezone to $TARGET_TIMEZONE"
    if [ -f "/usr/share/zoneinfo/$TARGET_TIMEZONE" ]; then
      if sudo ln -sf "/usr/share/zoneinfo/$TARGET_TIMEZONE" /etc/localtime \
        && sudo dpkg-reconfigure --frontend noninteractive tzdata; then
        log_success "Timezone updated to $TARGET_TIMEZONE."
      else
        log_error "Timezone update failed."
        add_error "Timezone update failed"
      fi
    else
      log_error "Timezone data not found: /usr/share/zoneinfo/$TARGET_TIMEZONE"
      add_error "Timezone data missing: $TARGET_TIMEZONE"
    fi
  fi
else
  log_skip "Timezone change disabled (SET_TIMEZONE=0)."
fi

if is_enabled "$INSTALL_CORE_PACKAGES"; then
  log_step "Installing core packages"
  packages=(
    curl git wget ca-certificates
    xdg-utils pulseaudio build-essential net-tools ripgrep jq lftp moreutils btop
    bat zip zstd gnupg2 bind9-dnsutils strace
    python3 python3-pip python-is-python3
    ffmpeg 7zip poppler-utils fd-find zoxide imagemagick exiftool
  )
  if [ "$IS_WSL" -eq 1 ]; then
    packages+=(wslu)
  else
    log_info "Skipping wslu (WSL-only)."
  fi

  if sudo apt-get install -y "${packages[@]}"; then
    log_success "Core packages install completed."
  else
    log_error "Core packages install reported errors."
    add_error "Core packages install failed"
  fi

  log_step "Verifying core packages"
  missing_pkgs=()
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log_success "Package ok: $pkg"
    else
      log_warn "Package missing: $pkg"
      missing_pkgs+=("$pkg")
    fi
  done
  if [ "${#missing_pkgs[@]}" -gt 0 ]; then
    add_error "Missing packages: ${missing_pkgs[*]}"
  fi
fi

log_step "Ensure bat symlink"
if [ -x /usr/bin/batcat ]; then
  if [ -L "$HOME/.local/bin/bat" ] \
    && [ "$(readlink -f "$HOME/.local/bin/bat")" = "/usr/bin/batcat" ]; then
    log_success "bat symlink already set."
  elif [ -e "$HOME/.local/bin/bat" ]; then
    log_warn "~/.local/bin/bat exists and is not the expected symlink."
    add_manual "Review ~/.local/bin/bat and point it to /usr/bin/batcat if needed."
  else
    if ln -s /usr/bin/batcat "$HOME/.local/bin/bat"; then
      log_success "Created bat symlink."
    else
      log_error "Failed to create bat symlink."
      add_error "bat symlink creation failed"
    fi
  fi
else
  log_warn "batcat not found. Skipping bat symlink."
  add_error "batcat missing"
fi

log_step "Install jq (latest) to ~/.local/bin"
if [ -x "$HOME/.local/bin/jq" ]; then
  log_success "jq already exists in ~/.local/bin."
else
  if command -v curl >/dev/null 2>&1; then
    if curl -sL https://github.com/jqlang/jq/releases/latest/download/jq-linux64 \
      -o "$HOME/.local/bin/jq" \
      && chmod +x "$HOME/.local/bin/jq"; then
      if "$HOME/.local/bin/jq" --version >/dev/null 2>&1; then
        log_success "jq installed to ~/.local/bin."
      else
        log_warn "jq installed but version check failed."
        add_error "jq version check failed"
      fi
    else
      log_error "jq download failed."
      add_error "jq download failed"
    fi
  else
    log_error "curl not available; cannot install jq."
    add_error "curl missing for jq"
  fi
fi

log_step "Install yq (latest) to ~/.local/bin"
if [ -x "$HOME/.local/bin/yq" ]; then
  log_success "yq already exists in ~/.local/bin."
else
  if command -v curl >/dev/null 2>&1; then
    if curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
      -o "$HOME/.local/bin/yq" \
      && chmod +x "$HOME/.local/bin/yq"; then
      if "$HOME/.local/bin/yq" --version >/dev/null 2>&1; then
        log_success "yq installed to ~/.local/bin."
      else
        log_warn "yq installed but version check failed."
        add_error "yq version check failed"
      fi
    else
      log_error "yq download failed."
      add_error "yq download failed"
    fi
  else
    log_error "curl not available; cannot install yq."
    add_error "curl missing for yq"
  fi
fi

log_step "Install dotslash"
if [ -x "$HOME/.local/bin/dotslash" ]; then
  log_success "dotslash already installed."
else
  if command -v curl >/dev/null 2>&1; then
    arch="$(uname -m)"
    url="https://github.com/facebook/dotslash/releases/latest/download/dotslash-ubuntu-22.04.${arch}.tar.gz"
    if curl -LSfs "$url" | tar fxz - -C "$HOME/.local/bin"; then
      log_success "dotslash installed."
    else
      log_error "dotslash install failed."
      add_error "dotslash install failed"
    fi
  else
    log_error "curl not available; cannot install dotslash."
    add_error "curl missing for dotslash"
  fi
fi

if is_enabled "$INSTALL_BETTER_RM"; then
  log_step "Install better-rm"
  if command -v better-rm >/dev/null 2>&1 || [ -x "$HOME/.local/bin/rm" ]; then
    log_success "better-rm appears to be installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -sSL https://raw.githubusercontent.com/doggy8088/better-rm/main/install.sh | bash; then
        log_success "better-rm install script completed."
      else
        log_error "better-rm install failed."
        add_error "better-rm install failed"
      fi
    else
      log_error "curl not available; cannot install better-rm."
      add_error "curl missing for better-rm"
    fi
  fi
  if rm --version >/dev/null 2>&1; then
    log_info "rm --version: $(rm --version | head -n1)"
  else
    log_warn "rm --version check failed."
  fi
else
  log_skip "better-rm install disabled (INSTALL_BETTER_RM=0)."
fi

if is_enabled "$INSTALL_RUST"; then
  log_step "Install Rust (rustup)"
  if command -v rustup >/dev/null 2>&1; then
    log_success "rustup already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y; then
        log_success "rustup installer completed."
      else
        log_error "rustup install failed."
        add_error "rustup install failed"
      fi
    else
      log_error "curl not available; cannot install rustup."
      add_error "curl missing for rustup"
    fi
  fi
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.cargo/env"
  fi
  if command -v rustup >/dev/null 2>&1; then
    if rustup update stable; then
      log_success "Rust updated to stable."
    else
      log_error "Rust update failed."
      add_error "Rust update failed"
    fi
  fi
else
  log_skip "Rust install disabled (INSTALL_RUST=0)."
fi

if is_enabled "$INSTALL_YAZI"; then
  log_step "Install yazi (requires Rust)"
  if command -v cargo >/dev/null 2>&1; then
    if cargo install --locked yazi-fm yazi-cli; then
      log_success "yazi installed."
    else
      log_error "yazi install failed."
      add_error "yazi install failed"
    fi
  else
    log_error "cargo not found; cannot install yazi."
    add_error "cargo missing for yazi"
  fi

  if command -v ya >/dev/null 2>&1; then
    if ya pkg add yazi-rs/flavors:catppuccin-frappe; then
      log_success "yazi theme installed."
    else
      log_warn "yazi theme install failed."
    fi
    mkdir -p "$HOME/.config/yazi"
    cat <<'EOF' > "$HOME/.config/yazi/theme.toml"
[flavor]
dark = "catppuccin-frappe"
EOF
  else
    log_warn "ya command not found; skipping yazi theme."
  fi

  yazi_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:yazi >>>
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
# <<< quick-setup-ubuntu-24:yazi <<<
EOF
)
  append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:yazi" "$yazi_block"
else
  log_skip "yazi install disabled (INSTALL_YAZI=0)."
fi

if is_enabled "$INSTALL_NODE"; then
  log_step "Install nvm and Node.js"
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    log_success "nvm already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      nvm_tag=$(get_latest_github_tag "nvm-sh/nvm")
      if [ -n "$nvm_tag" ] && [ "$nvm_tag" != "null" ]; then
        if curl -s -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" | bash; then
          log_success "nvm installed ($nvm_tag)."
        else
          log_error "nvm install failed."
          add_error "nvm install failed"
        fi
      else
        log_error "Failed to detect latest nvm version."
        add_error "nvm version detection failed"
      fi
    else
      log_error "curl not available; cannot install nvm."
      add_error "curl missing for nvm"
    fi
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      # shellcheck disable=SC1090
      . "$NVM_DIR/nvm.sh"
    fi
  fi

  if command -v nvm >/dev/null 2>&1; then
    if nvm install "$NODE_VERSION" \
      && nvm use "$NODE_VERSION" \
      && nvm alias default "$NODE_VERSION"; then
      log_success "Node.js $NODE_VERSION installed and set as default."
      log_info "Node version: $(node -v 2>/dev/null || true)"
    else
      log_error "Node.js install via nvm failed."
      add_error "Node.js install failed"
    fi
  else
    log_error "nvm not available after install."
    add_error "nvm unavailable"
  fi
else
  log_skip "Node.js install disabled (INSTALL_NODE=0)."
fi

log_step "Configure shell files"
if [ "$IS_WSL" -eq 1 ] && command -v powershell.exe >/dev/null 2>&1; then
  profile_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:profile >>>
# WSL: Windows username
export WINDOWS_USERNAME=$(powershell.exe '$env:UserName' 2>/dev/null | tr -d '\r')

# Brighter colors for jq on dark backgrounds
export JQ_COLORS="33:93:93:96:92:97:1;97:4;97"

export EDITOR=vim
export GPG_TTY=$(tty)
# <<< quick-setup-ubuntu-24:profile <<<
EOF
)
else
  profile_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:profile >>>
# Brighter colors for jq on dark backgrounds
export JQ_COLORS="33:93:93:96:92:97:1;97:4;97"

export EDITOR=vim
export GPG_TTY=$(tty)
# <<< quick-setup-ubuntu-24:profile <<<
EOF
)
fi
append_block "$HOME/.profile" "quick-setup-ubuntu-24:profile" "$profile_block"

bashrc_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:bashrc >>>
# Enable programmable completion features
shopt -u direxpand
shopt -s no_empty_cmd_completion
# <<< quick-setup-ubuntu-24:bashrc <<<
EOF
)
append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:bashrc" "$bashrc_block"

inputrc_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:inputrc >>>
set bell-style none
# <<< quick-setup-ubuntu-24:inputrc <<<
EOF
)
append_block "$HOME/.inputrc" "quick-setup-ubuntu-24:inputrc" "$inputrc_block"

if [ "$IS_WSL" -eq 1 ] && is_enabled "$ENABLE_WSL_LOCAL_VAR"; then
  wsl_local_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:wsl-local >>>
export local=$(ip route show default | awk '{print $3}')
# <<< quick-setup-ubuntu-24:wsl-local <<<
EOF
)
  append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:wsl-local" "$wsl_local_block"
fi

log_step "SSH key setup"
if [ -f "$HOME/.ssh/id_rsa" ]; then
  log_success "SSH key already exists."
else
  if command -v ssh-keygen >/dev/null 2>&1; then
    mkdir -p "$HOME/.ssh"
    if ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -P ""; then
      log_success "SSH key created."
    else
      log_error "SSH key generation failed."
      add_error "SSH key generation failed"
    fi
  else
    log_error "ssh-keygen not found."
    add_error "ssh-keygen missing"
  fi
fi
touch "$HOME/.ssh/authorized_keys"
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/authorized_keys"
add_manual "Add your SSH public key to GitHub: cat ~/.ssh/id_rsa.pub"

log_step "Create ~/projects workspace"
if mkdir -p "$HOME/projects"; then
  log_success "Workspace ready at ~/projects."
else
  log_error "Failed to create ~/projects."
  add_error "mkdir ~/projects failed"
fi

if command -v code >/dev/null 2>&1; then
  add_manual "Open VS Code in WSL when ready: code ."
else
  log_info "VS Code 'code' command not found. Skipping auto-open."
fi

if is_enabled "$INSTALL_STARSHIP"; then
  log_step "Install Starship prompt"
  if command -v starship >/dev/null 2>&1; then
    log_success "Starship already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
        log_success "Starship installed."
      else
        log_error "Starship install failed."
        add_error "Starship install failed"
      fi
    else
      log_error "curl not available; cannot install Starship."
      add_error "curl missing for Starship"
    fi
  fi

  if command -v starship >/dev/null 2>&1; then
    mkdir -p "$HOME/.config"
    if [ ! -f "$HOME/.config/starship.toml" ]; then
      if starship preset catppuccin-powerline -o "$HOME/.config/starship.toml"; then
        log_success "Starship preset applied."
      else
        log_warn "Failed to apply Starship preset."
      fi
    else
      log_info "Starship config exists; leaving as-is."
    fi

    if grep -q "^\[line_break\]" "$HOME/.config/starship.toml" 2>/dev/null; then
      if sed -i '/^\[line_break\]/,/^\[/ s/disabled = true/disabled = false/' \
        "$HOME/.config/starship.toml"; then
        log_success "Starship line_break enabled."
      else
        log_warn "Failed to update Starship line_break."
      fi
    else
      log_warn "Starship line_break section not found; manual tweak may be needed."
    fi

    starship_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:starship >>>
eval "$(starship init bash)"
# <<< quick-setup-ubuntu-24:starship <<<
EOF
)
    append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:starship" "$starship_block"
  fi
else
  log_skip "Starship install disabled (INSTALL_STARSHIP=0)."
fi

if is_enabled "$INSTALL_FZF"; then
  log_step "Install fzf"
  if [ -d "$HOME/.fzf" ]; then
    log_success "fzf already installed."
  else
    if command -v git >/dev/null 2>&1; then
      if git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"; then
        if "$HOME/.fzf/install" --all; then
          log_success "fzf installed."
        else
          log_error "fzf install script failed."
          add_error "fzf install failed"
        fi
      else
        log_error "fzf git clone failed."
        add_error "fzf clone failed"
      fi
    else
      log_error "git not available; cannot install fzf."
      add_error "git missing for fzf"
    fi
  fi

  fzf_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:fzf >>>
export FZF_CTRL_R_OPTS='--bind=tab:accept'
# <<< quick-setup-ubuntu-24:fzf <<<
EOF
)
  append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:fzf" "$fzf_block"
else
  log_skip "fzf install disabled (INSTALL_FZF=0)."
fi

if is_enabled "$RUN_GIT_SETUP"; then
  log_step "Run git setup"
  if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    if command -v npx >/dev/null 2>&1; then
      if npx -y @willh/git-setup --name "$GIT_NAME" --email "$GIT_EMAIL"; then
        log_success "Git setup completed."
      else
        log_error "Git setup failed."
        add_error "Git setup failed"
      fi
    else
      log_error "npx not available; cannot run git setup."
      add_error "npx missing for git setup"
    fi
  else
    log_warn "GIT_NAME and GIT_EMAIL not set; skipping git setup."
    add_manual "Set GIT_NAME and GIT_EMAIL, then run: npx -y @willh/git-setup --name \"Your Name\" --email you@example.com"
  fi
else
  log_skip "Git setup disabled (RUN_GIT_SETUP=0)."
fi

if [ "$IS_WSL" -eq 1 ] && is_enabled "$CONFIG_GIT_GCM_WSL"; then
  log_step "Configure Git Credential Manager (WSL)"
  gcm_path="/mnt/c/PROGRA~1/Git/mingw64/bin/git-credential-manager.exe"
  if [ -x "$gcm_path" ]; then
    if git config --global credential.helper "$gcm_path"; then
      log_success "Git Credential Manager configured."
    else
      log_error "Failed to set Git Credential Manager."
      add_error "Git Credential Manager config failed"
    fi
  else
    log_warn "GCM not found at $gcm_path"
    add_manual "Install Git for Windows and re-run: git config --global credential.helper \"$gcm_path\""
  fi
fi

if is_enabled "$CONFIG_AZURE_DEVOPS_GIT"; then
  log_step "Configure Azure DevOps git auth settings"
  if git config --global credential.https://dev.azure.com.useHttpPath true; then
    log_success "Azure DevOps git auth setting configured."
  else
    log_error "Failed to configure Azure DevOps git auth setting."
    add_error "Azure DevOps git auth setting failed"
  fi
fi

log_step "Configure Vim"
vim_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:vimrc >>>
syntax on
set encoding=utf-8
set background=dark

let &t_SI .= "\<Esc>[?2004h"
let &t_EI .= "\<Esc>[?2004l"

inoremap <special> <expr> <Esc>[200~ XTermPasteBegin()

function! XTermPasteBegin()
  set pastetoggle=<Esc>[201~
  set paste
  return ""
endfunction

" Treat .log as messages
augroup LogSyntax
  autocmd!
  autocmd BufNewFile,BufRead *.log setlocal filetype=messages
augroup END

augroup LogHighlight
  autocmd!
  autocmd FileType messages syntax match LogError "ERROR"
  autocmd FileType messages syntax match LogWarn  "WARN"
  autocmd FileType messages syntax match LogInfo  "INFO"
  autocmd FileType messages highlight LogError ctermfg=Red
  autocmd FileType messages highlight LogWarn  ctermfg=Yellow
  autocmd FileType messages highlight LogInfo  ctermfg=Cyan
augroup END
# <<< quick-setup-ubuntu-24:vimrc <<<
EOF
)
append_block "$HOME/.vimrc" "quick-setup-ubuntu-24:vimrc" "$vim_block"
if sudo cp "$HOME/.vimrc" /root/.vimrc; then
  log_success "Copied .vimrc to /root/.vimrc."
else
  log_warn "Failed to copy .vimrc to /root/.vimrc."
  add_error "Copy .vimrc to root failed"
fi

if is_enabled "$INSTALL_GH"; then
  log_step "Install GitHub CLI"
  if command -v gh >/dev/null 2>&1; then
    log_success "GitHub CLI already installed."
  else
    if ! command -v wget >/dev/null 2>&1; then
      run_cmd "Install wget" sudo apt-get install -y wget
    fi
    if command -v wget >/dev/null 2>&1; then
      sudo mkdir -p -m 755 /etc/apt/keyrings
      tmp_keyring="$(mktemp)"
      if wget -nv -O "$tmp_keyring" \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg < "$tmp_keyring" > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt-get update \
        && sudo apt-get install gh -y; then
        log_success "GitHub CLI installed."
      else
        log_error "GitHub CLI install failed."
        add_error "GitHub CLI install failed"
      fi
      rm -f "$tmp_keyring"
    else
      log_error "wget not available; cannot install GitHub CLI."
      add_error "wget missing for GitHub CLI"
    fi
  fi
  if command -v gh >/dev/null 2>&1; then
    gh help environment >/dev/null 2>&1 || true
    add_manual "Authenticate GitHub CLI: gh auth login --web -h github.com"
  fi
else
  log_skip "GitHub CLI install disabled (INSTALL_GH=0)."
fi

if is_enabled "$INSTALL_COPILOT"; then
  log_step "Install GitHub Copilot CLI"
  if command -v copilot >/dev/null 2>&1; then
    log_success "Copilot CLI already installed."
  else
    if command -v npm >/dev/null 2>&1; then
      if npm install -g @github/copilot; then
        log_success "Copilot CLI installed."
      else
        log_error "Copilot CLI install failed."
        add_error "Copilot CLI install failed"
      fi
    else
      log_error "npm not available; cannot install Copilot CLI."
      add_error "npm missing for Copilot CLI"
    fi
  fi
  if command -v copilot >/dev/null 2>&1; then
    log_info "Copilot version: $(copilot -v 2>/dev/null || true)"
    add_manual "Start Copilot CLI: copilot"
  fi
else
  log_skip "Copilot CLI install disabled (INSTALL_COPILOT=0)."
fi

if is_enabled "$INSTALL_AICHAT"; then
  log_step "Install AIChat"
  if command -v aichat >/dev/null 2>&1; then
    log_success "AIChat already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      aichat_tag=$(get_latest_github_tag "sigoden/aichat")
      if [ -n "$aichat_tag" ] && [ "$aichat_tag" != "null" ]; then
        if sudo bash -c \
          "curl -sL https://github.com/sigoden/aichat/releases/download/${aichat_tag}/aichat-${aichat_tag}-x86_64-unknown-linux-musl.tar.gz \
            | tar -xzO aichat > /usr/local/bin/aichat && chmod +x /usr/local/bin/aichat"; then
          log_success "AIChat installed."
        else
          log_error "AIChat install failed."
          add_error "AIChat install failed"
        fi
      else
        log_error "Failed to detect AIChat version."
        add_error "AIChat version detection failed"
      fi
    else
      log_error "curl not available; cannot install AIChat."
      add_error "curl missing for AIChat"
    fi
  fi

  if command -v aichat >/dev/null 2>&1; then
    log_info "AIChat version: $(aichat -V 2>/dev/null || true)"
    if [ -n "$GEMINI_API_KEY" ]; then
      aichat_block=$(cat <<EOF
# >>> quick-setup-ubuntu-24:aichat >>>
export GEMINI_API_KEY='${GEMINI_API_KEY}'
export AICHAT_PLATFORM=gemini
export AICHAT_MODEL=gemini:gemini-2.5-flash-lite-preview-06-17
# <<< quick-setup-ubuntu-24:aichat <<<
EOF
)
      append_block "$HOME/.profile" "quick-setup-ubuntu-24:aichat" "$aichat_block"
    else
      log_warn "GEMINI_API_KEY not set; AIChat env not configured."
      add_manual "Set GEMINI_API_KEY and add AIChat env vars to ~/.profile"
    fi

    if is_enabled "$AICHAT_SYNC_MODELS"; then
      if aichat --sync-models; then
        log_success "AIChat model list synced."
      else
        log_warn "AIChat model sync failed."
        add_error "AIChat model sync failed"
      fi
    fi
  fi
else
  log_skip "AIChat install disabled (INSTALL_AICHAT=0)."
fi

if is_enabled "$INSTALL_UV"; then
  log_step "Install uv"
  if command -v uv >/dev/null 2>&1; then
    log_success "uv already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log_success "uv install script completed."
      else
        log_error "uv install failed."
        add_error "uv install failed"
      fi
    else
      log_error "curl not available; cannot install uv."
      add_error "curl missing for uv"
    fi
  fi
  if command -v uv >/dev/null 2>&1; then
    log_info "uv version: $(uv -V 2>/dev/null || true)"
  else
    export PATH="$HOME/.cargo/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      log_info "uv version: $(uv -V 2>/dev/null || true)"
    fi
  fi
else
  log_skip "uv install disabled (INSTALL_UV=0)."
fi

if is_enabled "$INSTALL_CODEX"; then
  log_step "Install Codex CLI"
  if command -v codex >/dev/null 2>&1; then
    log_success "Codex CLI already installed."
  else
    if command -v npm >/dev/null 2>&1; then
      if npm install -g @openai/codex; then
        log_success "Codex CLI installed."
      else
        log_error "Codex CLI install failed."
        add_error "Codex CLI install failed"
      fi
    else
      log_error "npm not available; cannot install Codex CLI."
      add_error "npm missing for Codex CLI"
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    log_info "Codex CLI version: $(codex --version 2>/dev/null || true)"
    codex_block=$(cat <<'EOF'
# >>> quick-setup-ubuntu-24:codex >>>
eval "$(codex completion bash)"
# <<< quick-setup-ubuntu-24:codex <<<
EOF
)
    append_block "$HOME/.bashrc" "quick-setup-ubuntu-24:codex" "$codex_block"
    add_manual "Login to Codex: codex login"
  fi
else
  log_skip "Codex CLI install disabled (INSTALL_CODEX=0)."
fi

if is_enabled "$INSTALL_GEMINI"; then
  log_step "Install Gemini CLI"
  if command -v gemini >/dev/null 2>&1; then
    log_success "Gemini CLI already installed."
  else
    if command -v npm >/dev/null 2>&1; then
      if npm install -g @google/gemini-cli; then
        log_success "Gemini CLI installed."
      else
        log_error "Gemini CLI install failed."
        add_error "Gemini CLI install failed"
      fi
    else
      log_error "npm not available; cannot install Gemini CLI."
      add_error "npm missing for Gemini CLI"
    fi
  fi
  if command -v gemini >/dev/null 2>&1; then
    log_info "Gemini CLI version: $(gemini -v 2>/dev/null || true)"
    if [ ! -x "$HOME/.local/bin/gemini-init" ]; then
      if command -v curl >/dev/null 2>&1; then
        if curl -sSL https://github.com/doggy8088/gemini-init/raw/main/gemini-init \
          -o "$HOME/.local/bin/gemini-init" \
          && chmod +x "$HOME/.local/bin/gemini-init"; then
          log_success "gemini-init installed."
        else
          log_warn "gemini-init install failed."
        fi
      fi
    else
      log_success "gemini-init already installed."
    fi
    add_manual "Run Gemini login/setup: gemini"
    add_manual "Initialize Gemini settings: gemini-init"
  fi
else
  log_skip "Gemini CLI install disabled (INSTALL_GEMINI=0)."
fi

if is_enabled "$INSTALL_CLAUDE"; then
  log_step "Install Claude Code"
  if command -v claude >/dev/null 2>&1; then
    log_success "Claude Code already installed."
  else
    if command -v npm >/dev/null 2>&1; then
      if npm install -g @anthropic-ai/claude-code; then
        log_success "Claude Code installed."
      else
        log_error "Claude Code install failed."
        add_error "Claude Code install failed"
      fi
    else
      log_error "npm not available; cannot install Claude Code."
      add_error "npm missing for Claude Code"
    fi
  fi
  if command -v claude >/dev/null 2>&1; then
    log_info "Claude Code version: $(claude --version 2>/dev/null || true)"
  fi
else
  log_skip "Claude Code install disabled (INSTALL_CLAUDE=0)."
fi

if is_enabled "$INSTALL_SUPERCLAUDE"; then
  log_step "Install SuperClaude (requires uvx)"
  if command -v uvx >/dev/null 2>&1; then
    if uvx SuperClaude install; then
      log_success "SuperClaude installed."
    else
      log_error "SuperClaude install failed."
      add_error "SuperClaude install failed"
    fi
  else
    log_warn "uvx not available; cannot install SuperClaude."
    add_error "uvx missing for SuperClaude"
  fi
fi

if is_enabled "$INSTALL_AZURE_CLI"; then
  log_step "Install Azure CLI"
  if command -v az >/dev/null 2>&1; then
    log_success "Azure CLI already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; then
        log_success "Azure CLI installed."
      else
        log_error "Azure CLI install failed."
        add_error "Azure CLI install failed"
      fi
    else
      log_error "curl not available; cannot install Azure CLI."
      add_error "curl missing for Azure CLI"
    fi
  fi
  if command -v az >/dev/null 2>&1; then
    log_info "Azure CLI version: $(az version 2>/dev/null | head -n1 || true)"
    add_manual "Login to Azure: az login"
  fi
else
  log_skip "Azure CLI install disabled (INSTALL_AZURE_CLI=0)."
fi

if is_enabled "$INSTALL_GCLOUD"; then
  log_step "Install Google Cloud SDK"
  if command -v gcloud >/dev/null 2>&1; then
    log_success "Google Cloud SDK already installed."
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -sSL https://sdk.cloud.google.com | bash; then
        log_success "Google Cloud SDK install script completed."
      else
        log_error "Google Cloud SDK install failed."
        add_error "Google Cloud SDK install failed"
      fi
    else
      log_error "curl not available; cannot install Google Cloud SDK."
      add_error "curl missing for Google Cloud SDK"
    fi
  fi
  add_manual "Initialize gcloud: gcloud init"
else
  log_skip "Google Cloud SDK install disabled (INSTALL_GCLOUD=0)."
fi

log_step "Wrap-up"
add_manual "Reload shell: source ~/.profile && source ~/.bashrc"
if [ "${#manual_actions[@]}" -gt 0 ]; then
  log_tip "Manual actions to finish setup:"
  for action in "${manual_actions[@]}"; do
    log_tip "- $action"
  done
fi

if [ "${#errors[@]}" -gt 0 ]; then
  log_error "Some steps failed. Here is a clean summary:"
  for err in "${errors[@]}"; do
    log_error "- $err"
  done
  log_error "Please review the log: $LOG_FILE"
  log_error "Do not panic. Fixing this is totally doable. :)"
  exit 1
fi

log_success "All done! Your Ubuntu setup looks great. High five!"
log_tip "Log file saved at: $LOG_FILE"
