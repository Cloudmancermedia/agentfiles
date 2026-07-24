#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$SCRIPT_DIR/claude/skills"
TARGET_TOOL=${1:-}

if [[ -z "$TARGET_TOOL" ]]; then
    echo "Usage: $0 <claude|codex>"
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "No skills directory found at $SOURCE_DIR"
    exit 0
fi

case "$TARGET_TOOL" in
    claude)
        # CLAUDE_TARGET_DIR selects an alternate Claude home (claude case only;
        # codex is a single-home tool).
        TARGET_DIR="${CLAUDE_TARGET_DIR:-$HOME/.claude}/skills"
        PRESERVE_SYSTEM=false
        ;;
    codex)
        TARGET_DIR="$HOME/.codex/skills"
        PRESERVE_SYSTEM=true
        ;;
    *)
        echo "Unknown target tool: $TARGET_TOOL"
        echo "Usage: $0 <claude|codex>"
        exit 1
        ;;
esac

mkdir -p "$TARGET_DIR"

# This repo is the source of truth for custom skills. Clear unmanaged custom
# skills before copying so Claude Code and Codex stay in parity after sync.
if [[ "$PRESERVE_SYSTEM" == true ]]; then
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.system' -exec rm -rf {} +
else
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
fi

for skill_path in "$SOURCE_DIR"/*; do
    [[ -d "$skill_path" ]] || continue
    skill_name=$(basename "$skill_path")
    cp -R "$skill_path" "$TARGET_DIR/$skill_name"
done

if [[ "$PRESERVE_SYSTEM" == true ]]; then
    skill_count=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.system' | wc -l | tr -d ' ')
else
    skill_count=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi

echo "  -> $TARGET_DIR/ updated ($skill_count custom skills)"
