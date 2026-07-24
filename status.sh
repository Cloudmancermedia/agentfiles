#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== agentfiles Status ==="
echo ""

print_dir_entries() {
    local target_dir=$1
    local exclude_name=${2:-}

    if [[ ! -d "$target_dir" ]]; then
        echo "    (none)"
        return
    fi

    local found=false
    for path in "$target_dir"/*; do
        [[ -e "$path" ]] || continue
        [[ -n "$exclude_name" && "$(basename "$path")" == "$exclude_name" ]] && continue
        found=true
        echo "    - $(basename "$path")"
    done
    [[ "$found" == false ]] && echo "    (none)"
}

# Shorten $HOME back to ~ for display.
tilde() { local t="~"; echo "${1/#$HOME/$t}"; }

ENABLED_TOOLS=$(cat "$SCRIPT_DIR/local/.enabled-tools" 2>/dev/null || echo "claude")
echo "Enabled tools: $ENABLED_TOOLS"

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
    echo "  Behind remote by $BEHIND commit(s) — run ./sync.sh"
fi

# Per-home Claude state. Each home has its own bound profile, its own login, and
# its own deployed config.
if echo "$ENABLED_TOOLS" | grep -qw "claude"; then
    echo ""
    echo "=== Claude homes ==="
    while IFS=$'\t' read -r label profile dir; do
        [[ -n "$label" ]] || continue
        # The app-state file pairs with the home: ~/.claude.json for the default,
        # else <dir>/.claude.json.
        if [[ "$dir" == "$HOME/.claude" ]]; then
            claude_json="$HOME/.claude.json"
        else
            claude_json="$dir/.claude.json"
        fi

        echo ""
        echo "  [$label] profile: $profile  ->  $(tilde "$dir")"

        if [[ -f "$claude_json" ]]; then
            account=$(jq -r '.oauthAccount.emailAddress // "unknown"' "$claude_json" 2>/dev/null)
            org=$(jq -r '.oauthAccount.organizationName // "none"' "$claude_json" 2>/dev/null)
            echo "    account: $account (org: $org)"
        else
            echo "    account: (not logged in)"
        fi

        echo "    MCP servers:"
        if [[ -f "$claude_json" ]]; then
            servers=$(jq -r '.mcpServers // {} | keys[]' "$claude_json" 2>/dev/null)
            if [[ -n "$servers" ]]; then
                echo "$servers" | while read -r s; do echo "      - $s"; done
            else
                echo "      (none)"
            fi
        else
            echo "      (none)"
        fi

        if [[ -d "$dir/rules" ]]; then
            rules_count=$(find "$dir/rules" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
            echo "    rules: $rules_count file(s)"
        else
            echo "    rules: (none)"
        fi

        echo "    skills:"
        print_dir_entries "$dir/skills"
    done < <("$SCRIPT_DIR/scripts/resolve-homes.sh" 2>/dev/null)
fi

# Codex status (if enabled)
if echo "$ENABLED_TOOLS" | grep -qw "codex"; then
    echo ""
    echo "=== Codex CLI ==="
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
    echo "  Codex custom skills:"
    print_dir_entries ~/.codex/skills .system
fi
