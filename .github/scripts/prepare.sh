#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/motion-canvas/motion-canvas"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
REPO_ROOT="$(pwd)"

# --- Node version (Node 18) ---
# Docusaurus 2.4.0; v1 setup.sh uses Node 18 which works.
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
echo "[INFO] NPM $(npm --version) OK"

# --- Disable husky to avoid git hook issues ---
export HUSKY=0

# --- Dependencies (npm workspaces installs all packages from root) ---
npm install --ignore-scripts

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Pre-build steps: build workspace packages required by Docusaurus ---
# The docs site imports @motion-canvas/core, @motion-canvas/2d, @motion-canvas/player
# which must be compiled before docusaurus can run.
cd "$REPO_ROOT"

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

echo "[DONE] Repository is ready for docusaurus commands."
