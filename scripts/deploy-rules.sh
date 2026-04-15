#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1
RULES_DEST=~/.claude/rules

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

# Clear existing rules (remove stale rules from previous profile)
rm -rf "$RULES_DEST"
mkdir -p "$RULES_DEST"

# Deploy base rules first
if [[ -d "$SCRIPT_DIR/base/rules" ]]; then
    cp "$SCRIPT_DIR/base/rules/"*.md "$RULES_DEST/" 2>/dev/null || true
fi

# Deploy profile rules (can override base by name)
if [[ -d "$SCRIPT_DIR/profiles/$PROFILE/rules" ]]; then
    cp "$SCRIPT_DIR/profiles/$PROFILE/rules/"*.md "$RULES_DEST/" 2>/dev/null || true
fi

echo "  -> ~/.claude/rules/ updated ($(ls -1 "$RULES_DEST" | wc -l | tr -d ' ') files)"
