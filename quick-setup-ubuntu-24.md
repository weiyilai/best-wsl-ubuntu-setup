# quick-setup-ubuntu-24.sh

Quick setup script for Ubuntu 24.04 with WSL-aware behavior. It validates OS
version, skips WSL-only steps when not in WSL, and prints detailed, colorized
status for every step. A full log is saved to `~/quick-setup-ubuntu-24.log`.

## Requirements

- Ubuntu 24.04 only (script exits otherwise).
- `sudo` access.
- Network access for package installs and downloads.

## Usage

```bash
bash quick-setup-ubuntu-24.sh
```

Optional: make it executable.

```bash
chmod +x quick-setup-ubuntu-24.sh
./quick-setup-ubuntu-24.sh
```

## Behavior summary

- Verifies `/etc/os-release` is Ubuntu 24.04.
- Detects WSL (`/proc/version` or WSL env vars).
- Runs apt update/upgrade and installs common tools.
- Applies bash/profile/inputrc/Vim config blocks in an idempotent way.
- Installs optional tools controlled by env vars (see below).
- Collects errors and prints a clean summary at the end.
- Saves full output to `~/quick-setup-ubuntu-24.log`.

## Configuration (environment variables)

Use `VAR=1` or `VAR=0` to enable/disable. Defaults are shown in parentheses.

### Core toggles

- `SET_TIMEZONE` (1): update timezone to `TARGET_TIMEZONE`.
- `TARGET_TIMEZONE` (Asia/Taipei): timezone to set.
- `INSTALL_CORE_PACKAGES` (1): apt update/upgrade + essential packages.
- `INSTALL_BETTER_RM` (1): install better-rm.
- `INSTALL_RUST` (0): install Rust via rustup.
- `INSTALL_YAZI` (0): install yazi (requires Rust/cargo).
- `INSTALL_NODE` (1): install nvm + Node.
- `NODE_VERSION` (22): Node.js version for nvm.
- `INSTALL_STARSHIP` (1): install Starship prompt.
- `INSTALL_FZF` (1): install fzf.
- `RUN_GIT_SETUP` (0): run @willh/git-setup.
- `INSTALL_GH` (1): install GitHub CLI.
- `INSTALL_COPILOT` (1): install GitHub Copilot CLI.
- `INSTALL_AICHAT` (0): install AIChat.
- `AICHAT_SYNC_MODELS` (0): run `aichat --sync-models` after install.
- `INSTALL_UV` (1): install uv.
- `INSTALL_CODEX` (0): install Codex CLI.
- `INSTALL_GEMINI` (0): install Gemini CLI.
- `INSTALL_CLAUDE` (0): install Claude Code CLI.
- `INSTALL_SUPERCLAUDE` (0): install SuperClaude via uvx.
- `INSTALL_AZURE_CLI` (0): install Azure CLI.
- `INSTALL_GCLOUD` (0): install Google Cloud SDK.

### WSL-specific toggles

- `CONFIG_GIT_GCM_WSL` (1): set Git Credential Manager path in WSL.
- `ENABLE_WSL_LOCAL_VAR` (1): add `local` IP helper into `~/.bashrc`.

### Identity / credentials

- `GIT_NAME`: git user name for @willh/git-setup.
- `GIT_EMAIL`: git user email for @willh/git-setup.
- `GEMINI_API_KEY`: used to configure AIChat env when enabled.

## Examples

Minimal run (core only, no extra tools):

```bash
INSTALL_RUST=0 INSTALL_YAZI=0 INSTALL_AICHAT=0 INSTALL_CODEX=0 \
INSTALL_GEMINI=0 INSTALL_CLAUDE=0 INSTALL_SUPERCLAUDE=0 \
INSTALL_AZURE_CLI=0 INSTALL_GCLOUD=0 bash quick-setup-ubuntu-24.sh
```

Full setup with AI tools enabled:

```bash
INSTALL_AICHAT=1 INSTALL_CODEX=1 INSTALL_GEMINI=1 INSTALL_CLAUDE=1 \
INSTALL_SUPERCLAUDE=1 GEMINI_API_KEY="your-key" \
bash quick-setup-ubuntu-24.sh
```

Custom timezone:

```bash
TARGET_TIMEZONE="Asia/Tokyo" bash quick-setup-ubuntu-24.sh
```

## Notes

- The script is safe to re-run. It detects existing config markers and
  installed tools where possible.
- For WSL-only features, the script logs a skip message when not in WSL.
- After the run, check `~/quick-setup-ubuntu-24.log` if anything fails.
