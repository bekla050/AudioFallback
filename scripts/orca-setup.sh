#!/bin/zsh
# Orca-Setup für einen neuen Worktree: lokale Dateien aus dem Hauptcheckout
# verlinken und Swift-Pakete auflösen.
set -euo pipefail

WORKTREE="$(git rev-parse --show-toplevel)"
MAIN="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
cd "$WORKTREE"

if [[ "$WORKTREE" != "$MAIN" && -f "$MAIN/.env" && ! -e .env ]]; then
    ln -s "$MAIN/.env" .env
    echo ".env aus $MAIN verlinkt"
fi

swift package resolve
echo "Worktree bereit: $WORKTREE"
