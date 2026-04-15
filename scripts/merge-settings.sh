#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

CLAUDE_JSON=~/.claude.json
CLAUDE_SETTINGS=~/.claude/settings.json
BASE_MCP="$SCRIPT_DIR/base/mcp-servers-base.json"
PROFILE_MCP="$SCRIPT_DIR/profiles/$PROFILE/mcp-servers.json"
BASE_SETTINGS="$SCRIPT_DIR/base/settings.json"

# --- MCP Servers (-> ~/.claude.json) ---

# Read existing ~/.claude.json or create minimal object
if [[ -f "$CLAUDE_JSON" ]]; then
    EXISTING=$(cat "$CLAUDE_JSON")
else
    EXISTING='{}'
fi

# Merge MCP servers: base + profile
MCP_MERGED='{}'
if [[ -f "$BASE_MCP" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$BASE_MCP")
fi
if [[ -f "$PROFILE_MCP" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$PROFILE_MCP")
fi

# Variable substitution: resolve {{HOME}} to actual home directory
MCP_MERGED=$(echo "$MCP_MERGED" | sed "s|{{HOME}}|$HOME|g")

# Update ~/.claude.json with merged MCP servers (preserve other settings)
echo "$EXISTING" | jq --argjson mcp "$MCP_MERGED" '.mcpServers = $mcp' > "$CLAUDE_JSON"

echo "  -> ~/.claude.json MCP servers updated"

# --- Claude Code Settings (-> ~/.claude/settings.json) ---

if [[ -f "$BASE_SETTINGS" ]]; then
    mkdir -p ~/.claude
    cp "$BASE_SETTINGS" "$CLAUDE_SETTINGS"
    echo "  -> ~/.claude/settings.json updated"
fi
