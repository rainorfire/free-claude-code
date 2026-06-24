#!/usr/bin/env bash
# Build and pack free-claude-code for Linux tar deployment.
#
# Run on a Linux machine (x64 or arm64). The package includes platform-specific
# ripgrep binaries and must NOT be built on macOS/Windows for Linux targets.
#
# Usage:
#   ./scripts/package-linux-tar.sh
#   ./scripts/package-linux-tar.sh --skip-build    # reuse existing dist/
#   OUTPUT_DIR=./release ./scripts/package-linux-tar.sh
#
# Output:
#   release/free-claude-code-linux-<arch>-v<version>.tar.gz
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_BUILD=0
FORCE=0
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT}/release}"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

log() { echo "[pack] $*"; }
die() { echo "[pack] ERROR: $*" >&2; exit 1; }

if [ "$(uname -s)" != "Linux" ] && [ "$FORCE" -ne 1 ]; then
  die "This script must run on Linux (ripgrep + native deps are platform-specific). Pass --force to override."
fi

if ! command -v bun >/dev/null 2>&1; then
  die "Bun is required for building. Install: curl -fsSL https://bun.sh/install | bash"
fi

if ! command -v node >/dev/null 2>&1; then
  die "Node.js is required for staging runtime dependencies."
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH_TAG=x64 ;;
  aarch64|arm64) ARCH_TAG=arm64 ;;
  *) ARCH_TAG="$ARCH" ;;
esac

VERSION="$(node -p "require('./package.json').version")"
PKG_NAME="free-claude-code-linux-${ARCH_TAG}-v${VERSION}"
STAGE="${OUTPUT_DIR}/${PKG_NAME}"

log "Platform: linux-${ARCH_TAG}, version ${VERSION}"

if [ "$SKIP_BUILD" -eq 0 ]; then
  log "Installing dependencies..."
  bun install

  log "Downloading Linux ripgrep (postinstall)..."
  node scripts/postinstall.cjs

  log "Building dist/..."
  bun run build
else
  log "Skipping build (--skip-build)"
  [ -d dist ] || die "dist/ not found — run without --skip-build first"
fi

[ -f dist/cli-node.js ] || die "dist/cli-node.js missing — build failed?"
RG_BIN="dist/vendor/ripgrep/${ARCH}-linux/rg"
if [ ! -x "$RG_BIN" ]; then
  log "WARN: ${RG_BIN} not found — run 'node scripts/postinstall.cjs' on Linux before packing"
fi

log "Checking bundle integrity..."
if ! bun scripts/check-bundle-integrity.ts ./dist; then
  log "WARN: bundle integrity reported issues — tar will still include runtime node_modules"
fi

log "Staging ${STAGE}..."
rm -rf "$STAGE"
mkdir -p "$STAGE/dist"
cp -a dist/. "$STAGE/dist/"

# Minimal runtime package.json — external modules not bundled into dist/
cat > "$STAGE/package.json" <<EOF
{
  "name": "free-claude-code-runtime",
  "private": true,
  "type": "module",
  "version": "${VERSION}",
  "dependencies": {
    "@agentclientprotocol/sdk": "^0.19.0",
    "@claude-code-best/mcp-chrome-bridge": "^3.0.1",
    "highlight.js": "^11.11.1",
    "ws": "^8.20.0",
    "node-fetch": "^3.3.2"
  }
}
EOF

log "Installing production node_modules into staging..."
(
  cd "$STAGE"
  npm install --omit=dev --ignore-scripts --no-audit --no-fund 2>&1 | tail -5
)

cp scripts/install-linux-tar.sh "$STAGE/install.sh"
chmod +x "$STAGE/install.sh"

cat > "$STAGE/DEPLOY.md" <<EOF
# free-claude-code Linux tar 部署包

版本: ${VERSION}
平台: linux-${ARCH_TAG}

## 目标机器要求

- Linux x64 或 arm64
- Node.js 18+（推荐 20 LTS）
- 无需 Bun、无需 Claude 账号登录

## 安装

\`\`\`bash
tar xzf ${PKG_NAME}.tar.gz
cd ${PKG_NAME}
sudo ./install.sh
\`\`\`

自定义安装路径:

\`\`\`bash
INSTALL_DIR=\$HOME/claude-code ./install.sh
\`\`\`

## 使用（headless / Python 脚本）

\`\`\`bash
export ANTHROPIC_API_KEY=sk-ant-xxx
echo "say hi" | claude -p
\`\`\`

代理 / 自建 Anthropic 协议端点:

\`\`\`bash
export ANTHROPIC_API_KEY=任意值
export ANTHROPIC_BASE_URL=https://your-proxy.example.com
echo "say hi" | claude -p
\`\`\`

OpenAI 兼容端点:

\`\`\`bash
export CLAUDE_CODE_USE_OPENAI=1
export OPENAI_API_KEY=sk-xxx
export OPENAI_BASE_URL=https://api.deepseek.com/v1
export OPENAI_MODEL=deepseek-chat
echo "say hi" | claude -p
\`\`\`

## 卸载

\`\`\`bash
sudo ./install.sh --uninstall
\`\`\`
EOF

mkdir -p "$OUTPUT_DIR"
TARBALL="${OUTPUT_DIR}/${PKG_NAME}.tar.gz"
log "Creating ${TARBALL}..."
tar -C "$OUTPUT_DIR" -czf "$TARBALL" "$PKG_NAME"

BYTES="$(wc -c < "$TARBALL" | tr -d ' ')"
MB="$(awk "BEGIN {printf \"%.1f\", ${BYTES}/1024/1024}")"

log "Done."
echo ""
echo "  Package : ${TARBALL} (${MB} MB)"
echo "  Install : tar xzf ${PKG_NAME}.tar.gz && cd ${PKG_NAME} && sudo ./install.sh"
echo "  Test    : ANTHROPIC_API_KEY=sk-xxx claude --version"
