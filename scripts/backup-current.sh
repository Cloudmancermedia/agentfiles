#!/bin/bash
set -e

BACKUP_DIR=~/.agentfiles-backups
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_DIR/$TIMESTAMP"

has_current_config() {
    [[ -f ~/.claude/CLAUDE.md ]] && return 0
    [[ -f ~/.claude/settings.json ]] && return 0
    [[ -f ~/.claude.json ]] && return 0
    [[ -d ~/.claude/rules ]] && return 0
    [[ -d ~/.claude/skills ]] && return 0
    [[ -f ~/.codex/AGENTS.md ]] && return 0
    [[ -f ~/.codex/config.toml ]] && return 0
    [[ -f ~/.codex/hooks.json ]] && return 0
    [[ -d ~/.codex/skills ]] && return 0
    return 1
}

if ! has_current_config; then
    echo "No existing Claude Code or Codex CLI config found to back up."
    exit 0
fi

suffix=1
while [[ -e "$DEST" ]]; do
    DEST="$BACKUP_DIR/$TIMESTAMP-$suffix"
    suffix=$((suffix + 1))
done

mkdir -p "$DEST"

CLAUDE_DEST="$DEST/claude"
CODEX_DEST="$DEST/codex"

[[ -f ~/.claude/CLAUDE.md ]] && mkdir -p "$CLAUDE_DEST" && cp ~/.claude/CLAUDE.md "$CLAUDE_DEST/"
[[ -f ~/.claude/settings.json ]] && mkdir -p "$CLAUDE_DEST" && cp ~/.claude/settings.json "$CLAUDE_DEST/"
[[ -f ~/.claude.json ]] && mkdir -p "$CLAUDE_DEST" && cp ~/.claude.json "$CLAUDE_DEST/"
if [[ -d ~/.claude/rules ]]; then
    mkdir -p "$CLAUDE_DEST/rules"
    cp ~/.claude/rules/*.md "$CLAUDE_DEST/rules/" 2>/dev/null || true
fi
if [[ -d ~/.claude/skills ]]; then
    mkdir -p "$CLAUDE_DEST"
    cp -R ~/.claude/skills "$CLAUDE_DEST/"
fi

[[ -f ~/.codex/AGENTS.md ]] && mkdir -p "$CODEX_DEST" && cp ~/.codex/AGENTS.md "$CODEX_DEST/"
[[ -f ~/.codex/config.toml ]] && mkdir -p "$CODEX_DEST" && cp ~/.codex/config.toml "$CODEX_DEST/"
[[ -f ~/.codex/hooks.json ]] && mkdir -p "$CODEX_DEST" && cp ~/.codex/hooks.json "$CODEX_DEST/"
if [[ -d ~/.codex/skills ]]; then
    mkdir -p "$CODEX_DEST"
    cp -R ~/.codex/skills "$CODEX_DEST/"
fi

echo "Backup saved to: $DEST"

# Keep only last 10 backups
if [[ -d "$BACKUP_DIR" ]]; then
    cd "$BACKUP_DIR"
    ls -1t | tail -n +11 | while read -r dir; do rm -rf "$dir"; done
fi
