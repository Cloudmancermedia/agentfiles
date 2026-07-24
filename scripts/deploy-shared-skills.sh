#!/bin/bash
set -euo pipefail

# Materializes the shared skill store at ~/.claude-shared/skills/ from
# claude/skills/ — the FULL set, because the store is a deploy-time release
# artifact, not a live skill surface: each Claude home links only the skills
# its profile allowlist names (deploy-profile.sh symlinks per skill). Keeping the
# store outside any home means the factory-zero teardown can rm -rf a home's
# skills/ without dangling another home's links, and branch switches in the git
# checkout never mutate live agents.
#
# rm-and-recopy per skill; stale store entries (source removed from the repo)
# are pruned. This script never touches anything outside ~/.claude-shared.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$SCRIPT_DIR/claude/skills"
STORE="$HOME/.claude-shared/skills"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: no skills source at $SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$STORE"

# Prune store entries whose repo source is gone.
for existing in "$STORE"/*/; do
    [[ -d "$existing" ]] || continue
    name=$(basename "$existing")
    if [[ ! -d "$SOURCE_DIR/$name" ]]; then
        rm -rf "$STORE/$name"
        echo "  -> pruned stale store skill: $name"
    fi
done

count=0
for skill_path in "$SOURCE_DIR"/*/; do
    [[ -d "$skill_path" ]] || continue
    name=$(basename "$skill_path")
    rm -rf "$STORE/$name"
    cp -R "$SOURCE_DIR/$name" "$STORE/$name"
    count=$((count + 1))
done

echo "  -> shared skill store materialized: $count skill(s) at $STORE"
