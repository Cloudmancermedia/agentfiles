#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Config Status ==="
echo ""

# Current profile
CURRENT_PROFILE=$(cat "$SCRIPT_DIR/local/.current-profile" 2>/dev/null || echo "(none)")
echo "Current profile: $CURRENT_PROFILE"

# Last sync
LAST_SYNC=$(cat "$SCRIPT_DIR/local/.last-sync" 2>/dev/null || echo "(never)")
echo "Last sync: $LAST_SYNC"

# Git status
echo ""
echo "Repository status:"
cd "$SCRIPT_DIR"
git fetch --quiet 2>/dev/null || true
LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "none")

if [[ "$REMOTE" == "none" ]]; then
    echo "  No upstream configured"
elif [[ "$LOCAL" == "$REMOTE" ]]; then
    echo "  Up to date with remote"
else
    BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
    echo "  Behind remote by $BEHIND commit(s)"
    echo "  Run ./sync.sh to update"
fi

# Current Claude account
echo ""
echo "Claude account:"
if [[ -f ~/.claude.json ]]; then
    ACCOUNT=$(jq -r '.oauthAccount.emailAddress // "unknown"' ~/.claude.json 2>/dev/null)
    ORG=$(jq -r '.oauthAccount.organizationName // "none"' ~/.claude.json 2>/dev/null)
    echo "  Email: $ACCOUNT"
    echo "  Organization: $ORG"
else
    echo "  No account info found"
fi

# MCP servers
echo ""
echo "Active MCP servers:"
if [[ -f ~/.claude.json ]]; then
    jq -r '.mcpServers // {} | keys[]' ~/.claude.json 2>/dev/null | while read server; do
        echo "  - $server"
    done
else
    echo "  (none)"
fi

# Rules files
echo ""
echo "Active rules files:"
if [[ -d ~/.claude/rules ]]; then
    for f in ~/.claude/rules/*.md; do
        [[ -f "$f" ]] && echo "  - $(basename "$f")"
    done
else
    echo "  (none)"
fi
