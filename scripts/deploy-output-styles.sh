#!/bin/bash
set -euo pipefail

# Deploy base/output-styles/*.md into a Claude home's output-styles/ directory.
#
# An output style is part of Claude Code's system prompt, so rules about how a
# reply is shaped hold better there than in CLAUDE.md or rules/, which arrive as
# context. https://code.claude.com/docs/en/output-styles
#
# A profile turns a style on with "outputStyle": "<name>" in its settings.json.
# The factory-zero teardown empties output-styles/ and strips outputStyle, so
# deploy-profile.sh runs this on every real profile.
#
# A style can pull in a shared file with an include marker on its own line:
#     <!-- include: base/style-pointer.md -->
# The line is replaced by that file's contents at deploy time, so text that also
# lives elsewhere (rules/, Codex's AGENTS.md) keeps one source.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# OUTPUT_STYLES_SOURCE_DIR overrides the style source (tests only); include
# paths always resolve against the repo root.
SOURCE_DIR="${OUTPUT_STYLES_SOURCE_DIR:-$SCRIPT_DIR/base/output-styles}"
# CLAUDE_TARGET_DIR selects an alternate Claude home (see deploy-factory-zero.sh).
TARGET_DIR="${CLAUDE_TARGET_DIR:-$HOME/.claude}/output-styles"

[[ -d "$SOURCE_DIR" ]] || exit 0

expand_includes() {
    local style=$1 line partial
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\<!--[[:space:]]*include:[[:space:]]*(.+\.md)[[:space:]]*--\>$ ]]; then
            partial="$SCRIPT_DIR/${BASH_REMATCH[1]}"
            if [[ ! -f "$partial" ]]; then
                echo "ERROR: $(basename "$style") includes missing file: ${BASH_REMATCH[1]}" >&2
                exit 1
            fi
            cat "$partial"
        else
            printf '%s\n' "$line"
        fi
    done < "$style"
}

mkdir -p "$TARGET_DIR"
count=0
for style in "$SOURCE_DIR"/*.md; do
    [[ -e "$style" ]] || continue
    expand_includes "$style" > "$TARGET_DIR/$(basename "$style")"
    count=$((count + 1))
done
echo "  -> output styles deployed ($count)"
