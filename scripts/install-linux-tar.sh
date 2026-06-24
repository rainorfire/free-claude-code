#!/usr/bin/env bash
# Install free-claude-code from a tar package on Linux.
#
# Usage:
#   sudo ./install-linux-tar.sh              # install to /opt/free-claude-code
#   INSTALL_DIR=$HOME/claude-code ./install-linux-tar.sh
#   sudo ./install-linux-tar.sh --uninstall
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/free-claude-code}"
BIN_LINK="${BIN_LINK:-/usr/local/bin/claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[install] $*"; }
die() { echo "[install] ERROR: $*" >&2; exit 1; }

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    die "Node.js 18+ is required. Install Node 20 LTS first."
  fi
  local major
  major="$(node -p "process.versions.node.split('.')[0]")"
  if [ "$major" -lt 18 ]; then
    die "Node.js 18+ is required (found $(node -v))."
  fi
}

uninstall() {
  log "Removing ${BIN_LINK}"
  rm -f "$BIN_LINK"
  if [ -d "$INSTALL_DIR" ]; then
    log "Removing ${INSTALL_DIR}"
    rm -rf "$INSTALL_DIR"
  fi
  log "Uninstall complete."
}

install() {
  require_node

  [ -f "${SCRIPT_DIR}/dist/cli-node.js" ] || die "dist/cli-node.js not found — run this script from the extracted tar root."

  log "Installing to ${INSTALL_DIR}"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -a "${SCRIPT_DIR}/." "$INSTALL_DIR/"
  fi

  chmod +x "${INSTALL_DIR}/dist/cli-node.js" "${INSTALL_DIR}/dist/cli-bun.js" 2>/dev/null || true

  log "Linking ${BIN_LINK} -> ${INSTALL_DIR}/dist/cli-node.js"
  mkdir -p "$(dirname "$BIN_LINK")"
  ln -sf "${INSTALL_DIR}/dist/cli-node.js" "$BIN_LINK"

  log "Verifying installation..."
  "$BIN_LINK" --version

  cat <<EOF

Installed successfully.

  Command : claude
  Root    : ${INSTALL_DIR}
  Node    : $(node -v)

Headless example (no Claude account login required):

  export ANTHROPIC_API_KEY=sk-ant-xxx
  echo "say hi" | claude -p

Proxy / custom endpoint:

  export ANTHROPIC_API_KEY=any-value
  export ANTHROPIC_BASE_URL=https://your-proxy.example.com
  echo "say hi" | claude -p

OpenAI-compatible endpoint:

  export CLAUDE_CODE_USE_OPENAI=1
  export OPENAI_API_KEY=sk-xxx
  export OPENAI_BASE_URL=https://api.deepseek.com/v1
  export OPENAI_MODEL=deepseek-chat
  echo "say hi" | claude -p

EOF
}

case "${1:-}" in
  --uninstall) uninstall ;;
  -h|--help)
    echo "Usage: $0 [--uninstall]"
    echo "  INSTALL_DIR=/opt/free-claude-code  install destination (default: /opt/free-claude-code)"
    echo "  BIN_LINK=/usr/local/bin/claude     symlink target (default: /usr/local/bin/claude)"
    ;;
  *) install ;;
esac
