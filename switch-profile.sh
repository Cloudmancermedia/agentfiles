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

echo "=== Switching to profile: $PROFILE ==="
echo ""

# 1. Backup current config
"$SCRIPT_DIR/scripts/backup-current.sh"

# 2. Merge CLAUDE.md (base + profile)
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

# 3. Deploy rules files
echo "Deploying rules files..."
"$SCRIPT_DIR/scripts/deploy-rules.sh" "$PROFILE"

# 4. Merge MCP servers into ~/.claude.json
echo "Merging MCP servers..."
"$SCRIPT_DIR/scripts/merge-settings.sh" "$PROFILE"

# 5. Save current profile
mkdir -p "$SCRIPT_DIR/local"
echo "$PROFILE" > "$SCRIPT_DIR/local/.current-profile"

# 6. Remind about account switching
ACCOUNT_FILE="$SCRIPT_DIR/profiles/$PROFILE/account.txt"
echo ""
echo "=== Configuration switched to: $PROFILE ==="
echo ""
echo "NOTE: This only updates Claude Code configuration files (CLAUDE.md, rules,"
echo "MCP servers, settings). It does NOT switch your Claude Code account."
if [[ -f "$ACCOUNT_FILE" ]]; then
    echo ""
    echo "If this profile uses a different account, log out and back in:"
    echo "  claude /logout"
    echo "  claude  # then log in as: $(cat "$ACCOUNT_FILE")"
fi
