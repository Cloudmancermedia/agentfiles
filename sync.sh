#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_PROFILE=$(cat "$SCRIPT_DIR/local/.current-profile" 2>/dev/null || echo "")

if [[ -z "$CURRENT_PROFILE" ]]; then
    echo "No profile configured. Run ./install.sh first."
    exit 1
fi

echo "=== Syncing claudefiles ==="
echo "Current profile: $CURRENT_PROFILE"
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

# Merge CLAUDE.md
cat "$SCRIPT_DIR/base/CLAUDE.md" > ~/.claude/CLAUDE.md
if [[ -f "$SCRIPT_DIR/profiles/$CURRENT_PROFILE/CLAUDE.md.append" ]]; then
    echo "" >> ~/.claude/CLAUDE.md
    echo "---" >> ~/.claude/CLAUDE.md
    echo "" >> ~/.claude/CLAUDE.md
    cat "$SCRIPT_DIR/profiles/$CURRENT_PROFILE/CLAUDE.md.append" >> ~/.claude/CLAUDE.md
fi
echo "  -> ~/.claude/CLAUDE.md updated"

# Deploy rules files
"$SCRIPT_DIR/scripts/deploy-rules.sh" "$CURRENT_PROFILE"

# Merge settings
"$SCRIPT_DIR/scripts/merge-settings.sh" "$CURRENT_PROFILE"

# Record sync time
echo "$(date +%Y-%m-%d)" > "$SCRIPT_DIR/local/.last-sync"

echo ""
echo "=== Sync complete ==="
