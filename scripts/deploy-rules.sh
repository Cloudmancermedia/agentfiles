#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1
# CLAUDE_TARGET_DIR selects an alternate Claude home (default ~/.claude).
RULES_DEST="${CLAUDE_TARGET_DIR:-$HOME/.claude}/rules"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

# Clear existing rules (remove stale rules from previous profile)
rm -rf "$RULES_DEST"
mkdir -p "$RULES_DEST"

# Deploy base rules (shared across all tools)
if [[ -d "$SCRIPT_DIR/base/rules" ]]; then
    cp "$SCRIPT_DIR/base/rules/"*.md "$RULES_DEST/" 2>/dev/null || true
fi

# Deploy Claude-specific rules
if [[ -d "$SCRIPT_DIR/claude/rules" ]]; then
    cp "$SCRIPT_DIR/claude/rules/"*.md "$RULES_DEST/" 2>/dev/null || true
fi

# Deploy profile rules (can override base or claude rules by name)
if [[ -d "$SCRIPT_DIR/profiles/$PROFILE/rules" ]]; then
    cp "$SCRIPT_DIR/profiles/$PROFILE/rules/"*.md "$RULES_DEST/" 2>/dev/null || true
fi

echo "  -> $RULES_DEST/ updated ($(ls -1 "$RULES_DEST" | wc -l | tr -d ' ') files)"
