#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for motion-canvas/motion-canvas
# Runs from packages/docs (docusaurusRoot) on an existing source tree.
# This is a monorepo: @motion-canvas/core, @motion-canvas/2d, @motion-canvas/player
# must be built before Docusaurus can build. We navigate to the repo root to do this.

DOCS_DIR="$(pwd)"
REPO_ROOT="$(cd ../.. && pwd)"

# --- Node version (Node 18) ---
export NVM_DIR="${HOME}/.nvm"
if [ ! -f "${NVM_DIR}/nvm.sh" ]; then
    echo "[INFO] Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
# shellcheck disable=SC1091
source "${NVM_DIR}/nvm.sh"
nvm install 18
nvm use 18
echo "[INFO] Node $(node --version) OK"

# --- Disable husky ---
export HUSKY=0

# --- Dependencies (from repo root - npm workspaces) ---
cd "$REPO_ROOT"
npm install --ignore-scripts

# --- Pre-build steps: build workspace packages required by Docusaurus ---
echo "[INFO] Building @motion-canvas/core..."
npm run core:build

echo "[INFO] Bundling @motion-canvas/core..."
npm run core:bundle

echo "[INFO] Building @motion-canvas/2d..."
npm run 2d:build

echo "[INFO] Bundling @motion-canvas/2d..."
npm run 2d:bundle

echo "[INFO] Building @motion-canvas/player..."
npm run player:build

# --- Build Docusaurus site ---
cd "$DOCS_DIR"
echo "[INFO] Building Docusaurus site..."
NODE_OPTIONS=--max_old_space_size=4096 npx docusaurus build

echo "[DONE] Build complete."
