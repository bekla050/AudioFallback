#!/bin/zsh
# Orca-Archiv vor dem Entfernen eines Worktrees: laufende AudioFallback-Instanzen
# aus diesem Worktree beenden, damit keine Menüleisten-App ohne Binary übrig bleibt.
set -euo pipefail

WORKTREE="$(git rev-parse --show-toplevel)"

if pkill -f "^$WORKTREE/\\.build/.*AudioFallback"; then
    echo "AudioFallback aus $WORKTREE beendet"
fi
exit 0
