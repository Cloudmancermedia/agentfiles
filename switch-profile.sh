#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=${1:-}

# Validate profile
if [[ -z "$PROFILE" ]] || [[ ! -d "$SCRIPT_DIR/profiles/$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    echo ""
    echo "Available profiles:"
    ls -1 "$SCRIPT_DIR/profiles/"
    exit 1
fi

# Check if already on the requested profile
CURRENT_PROFILE_FILE="$SCRIPT_DIR/local/.current-profile"
if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
    CURRENT_PROFILE=$(cat "$CURRENT_PROFILE_FILE")
    if [[ "$CURRENT_PROFILE" == "$PROFILE" ]]; then
        echo "Already on profile: $PROFILE. Use ./sync.sh to reapply configuration."
        exit 0
    fi
fi

ENABLED_TOOLS=$(cat "$SCRIPT_DIR/local/.enabled-tools" 2>/dev/null || echo "claude")

echo "=== Switching to profile: $PROFILE ==="
echo ""

# 1. Backup current config
"$SCRIPT_DIR/scripts/backup-current.sh"

# 2. Deploy Claude Code configuration (if enabled)
if echo "$ENABLED_TOOLS" | grep -qw "claude"; then
    echo "Merging CLAUDE.md..."
    mkdir -p ~/.claude
    cat "$SCRIPT_DIR/base/CLAUDE.md" > ~/.claude/CLAUDE.md
    if [[ -f "$SCRIPT_DIR/profiles/$PROFILE/CLAUDE.md.append" ]]; then
        echo "" >> ~/.claude/CLAUDE.md
        echo "---" >> ~/.claude/CLAUDE.md
        echo "" >> ~/.claude/CLAUDE.md
        cat "$SCRIPT_DIR/profiles/$PROFILE/CLAUDE.md.append" >> ~/.claude/CLAUDE.md
    fi
    echo "  -> ~/.claude/CLAUDE.md updated"

    echo "Deploying rules files..."
    "$SCRIPT_DIR/scripts/deploy-rules.sh" "$PROFILE"

    echo "Merging MCP servers..."
    "$SCRIPT_DIR/scripts/merge-settings.sh" "$PROFILE"

    echo "Syncing Claude Code plugins..."
    "$SCRIPT_DIR/scripts/deploy-claude-plugins.sh"

    echo "Deploying Claude Code skills..."
    "$SCRIPT_DIR/scripts/deploy-skills.sh" claude
fi

# 3. Deploy Codex configuration (if enabled)
if echo "$ENABLED_TOOLS" | grep -qw "codex"; then
    echo ""
    echo "Deploying Codex configuration..."
    "$SCRIPT_DIR/scripts/deploy-codex.sh" "$PROFILE"
fi

# 4. Save current profile
mkdir -p "$SCRIPT_DIR/local"
echo "$PROFILE" > "$SCRIPT_DIR/local/.current-profile"

# 5. Remind about account switching
ACCOUNT_FILE="$SCRIPT_DIR/profiles/$PROFILE/account.txt"
echo ""
echo "=== Configuration switched to: $PROFILE ==="
echo ""
echo "NOTE: This only updates configuration files (CLAUDE.md, rules, MCP servers,"
echo "settings). It does NOT switch your accounts."
if [[ -f "$ACCOUNT_FILE" ]]; then
    echo ""
    echo "If this profile uses a different Claude account, log out and back in:"
    echo "  claude /logout"
    echo "  claude  # then log in as: $(cat "$ACCOUNT_FILE")"
fi
