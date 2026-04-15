#!/bin/bash
set -e

BACKUP_DIR=~/.claude-backups
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_DIR/$TIMESTAMP"

mkdir -p "$DEST"

[[ -f ~/.claude/CLAUDE.md ]] && cp ~/.claude/CLAUDE.md "$DEST/"
[[ -f ~/.claude/settings.json ]] && cp ~/.claude/settings.json "$DEST/"
[[ -f ~/.claude.json ]] && cp ~/.claude.json "$DEST/"
if [[ -d ~/.claude/rules ]]; then
    mkdir -p "$DEST/rules"
    cp ~/.claude/rules/*.md "$DEST/rules/" 2>/dev/null || true
fi

echo "Backup saved to: $DEST"

# Keep only last 10 backups
if [[ -d "$BACKUP_DIR" ]]; then
    cd "$BACKUP_DIR"
    ls -1t | tail -n +11 | while read -r dir; do rm -rf "$dir"; done
fi
