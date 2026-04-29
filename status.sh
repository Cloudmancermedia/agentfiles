#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== agentfiles Status ==="
echo ""

print_dir_entries() {
    local target_dir=$1
    local exclude_name=${2:-}

    if [[ ! -d "$target_dir" ]]; then
        echo "  (none)"
        return
    fi

    local found=false
    for path in "$target_dir"/*; do
        [[ -e "$path" ]] || continue
        [[ -n "$exclude_name" && "$(basename "$path")" == "$exclude_name" ]] && continue
        found=true
        echo "  - $(basename "$path")"
    done

    if [[ "$found" == false ]]; then
        echo "  (none)"
    fi
}

# Current profile
CURRENT_PROFILE=$(cat "$SCRIPT_DIR/local/.current-profile" 2>/dev/null || echo "(none)")
echo "Current profile: $CURRENT_PROFILE"

# Enabled tools
ENABLED_TOOLS=$(cat "$SCRIPT_DIR/local/.enabled-tools" 2>/dev/null || echo "claude")
echo "Enabled tools: $ENABLED_TOOLS"

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

echo ""
echo "Claude custom skills:"
print_dir_entries ~/.claude/skills

# Codex status (if enabled)
if echo "$ENABLED_TOOLS" | grep -qw "codex"; then
    echo ""
    echo "--- Codex CLI ---"
    if [[ -f ~/.codex/AGENTS.md ]]; then
        SECTIONS=$(grep -c '^## ' ~/.codex/AGENTS.md 2>/dev/null || echo "0")
        echo "  AGENTS.md: deployed ($SECTIONS rule sections)"
    else
        echo "  AGENTS.md: not deployed"
    fi
    if [[ -f ~/.codex/config.toml ]]; then
        MCP_COUNT=$(awk '/^\[mcp_servers\./ { count++ } END { print count + 0 }' ~/.codex/config.toml)
        echo "  config.toml: deployed ($MCP_COUNT MCP servers)"
    else
        echo "  config.toml: not deployed"
    fi
    echo "  Codex MCP servers:"
    if [[ -f ~/.codex/config.toml ]]; then
        grep '^\[mcp_servers\.' ~/.codex/config.toml 2>/dev/null | sed -E 's/^\[mcp_servers\.([^.]+)\]$/  - \1/' || echo "  (none)"
    else
        echo "  (none)"
    fi
    echo "  Codex custom skills:"
    print_dir_entries ~/.codex/skills .system
fi
