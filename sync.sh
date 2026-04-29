#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_PROFILE=$(cat "$SCRIPT_DIR/local/.current-profile" 2>/dev/null || echo "")

if [[ -z "$CURRENT_PROFILE" ]]; then
    echo "No profile configured. Run ./install.sh first."
    exit 1
fi

ENABLED_TOOLS="$SCRIPT_DIR/local/.enabled-tools"
TOOLS=$(cat "$ENABLED_TOOLS" 2>/dev/null || echo "claude")

echo "=== Syncing agentfiles ==="
echo "Current profile: $CURRENT_PROFILE"
echo "Enabled tools: $TOOLS"
echo ""

# Pull latest
echo "Pulling latest changes..."
cd "$SCRIPT_DIR"
git pull --ff-only || {
    echo ""
    echo "Warning: Could not fast-forward. You may have local changes."
    echo "Run 'git status' to check, then 'git pull --rebase' if needed."
    exit 1
}

# Reapply current profile (without logout/login)
echo ""
echo "Reapplying configuration..."

# Deploy Claude Code configuration (if enabled)
if echo "$TOOLS" | grep -qw "claude"; then
    cat "$SCRIPT_DIR/base/CLAUDE.md" > ~/.claude/CLAUDE.md
    if [[ -f "$SCRIPT_DIR/profiles/$CURRENT_PROFILE/CLAUDE.md.append" ]]; then
        echo "" >> ~/.claude/CLAUDE.md
        echo "---" >> ~/.claude/CLAUDE.md
        echo "" >> ~/.claude/CLAUDE.md
        cat "$SCRIPT_DIR/profiles/$CURRENT_PROFILE/CLAUDE.md.append" >> ~/.claude/CLAUDE.md
    fi
    echo "  -> ~/.claude/CLAUDE.md updated"

    "$SCRIPT_DIR/scripts/deploy-rules.sh" "$CURRENT_PROFILE"
    "$SCRIPT_DIR/scripts/merge-settings.sh" "$CURRENT_PROFILE"
    "$SCRIPT_DIR/scripts/deploy-claude-plugins.sh"

    # Deploy Claude Code skills
    "$SCRIPT_DIR/scripts/deploy-skills.sh" claude
fi

# Deploy Codex configuration (if enabled)
if echo "$TOOLS" | grep -qw "codex"; then
    echo ""
    "$SCRIPT_DIR/scripts/deploy-codex.sh" "$CURRENT_PROFILE"
fi

# Record sync time
echo "$(date +%Y-%m-%d)" > "$SCRIPT_DIR/local/.last-sync"

echo ""
echo "=== Sync complete ==="
