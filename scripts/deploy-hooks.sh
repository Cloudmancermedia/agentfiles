#!/bin/bash
set -euo pipefail

# Deploy hook scripts into a Claude home's hooks/ directory: base/hooks/ first
# (shared across profiles), then profiles/<profile>/hooks/ (can add or override
# by filename). Only regular files at the top level of each directory deploy, so
# base/hooks/examples/ never does.
#
# Unlike deploy-rules.sh, this does NOT empty the destination first: plugins and
# other tools may keep hooks in the same directory. The trade-off is that a hook
# removed from this repo stays in the deployed hooks/ until you delete it there
# by hand. It is inert once nothing registers it.
#
# Registration (the settings.json "hooks" block that tells Claude Code when to
# run a script) comes from base/settings.json and the profile's settings.json.
# This script only deploys the files that registration points at.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"
# CLAUDE_TARGET_DIR selects an alternate Claude home (see deploy-factory-zero.sh).
HOOKS_DEST="${CLAUDE_TARGET_DIR:-$HOME/.claude}/hooks"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>" >&2
    exit 1
fi

copied=0

deploy_dir() {
    local src="$1" f
    [[ -d "$src" ]] || return 0
    mkdir -p "$HOOKS_DEST"
    for f in "$src"/*; do
        [[ -f "$f" ]] || continue
        cp "$f" "$HOOKS_DEST/"
        case "$f" in
            *.sh) chmod +x "$HOOKS_DEST/$(basename "$f")" ;;
        esac
        copied=$((copied + 1))
    done
}

deploy_dir "$SCRIPT_DIR/base/hooks"
deploy_dir "$SCRIPT_DIR/profiles/$PROFILE/hooks"

if [[ "$copied" -gt 0 ]]; then
    echo "  -> $HOOKS_DEST/ updated ($copied files)"
fi
