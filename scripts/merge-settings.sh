#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

# CLAUDE_TARGET_DIR selects an alternate Claude home (default ~/.claude); the
# app-state file pairs with the home (~/.claude.json only for the default home).
CLAUDE_DIR="${CLAUDE_TARGET_DIR:-$HOME/.claude}"
if [[ "$CLAUDE_DIR" == "$HOME/.claude" ]]; then
    CLAUDE_JSON="$HOME/.claude.json"
else
    CLAUDE_JSON="$CLAUDE_DIR/.claude.json"
fi
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
BASE_MCP="$SCRIPT_DIR/base/mcp-servers-base.json"
PROFILE_MCP="$SCRIPT_DIR/profiles/$PROFILE/mcp-servers.json"
BASE_SETTINGS="$SCRIPT_DIR/base/settings.json"
PROFILE_SETTINGS="$SCRIPT_DIR/profiles/$PROFILE/settings.json"

# Ensure the target home exists before writing into it (a secondary home's
# app-state file lives inside it, so the dir must exist first).
mkdir -p "$CLAUDE_DIR"

# --- MCP Servers (-> app-state .claude.json) ---

# Read existing .claude.json or create minimal object
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

# Variable substitution: {{CLAUDE_DIR}} first (target home), then {{HOME}}
MCP_MERGED=$(echo "$MCP_MERGED" | sed -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" -e "s|{{HOME}}|$HOME|g")

# Update the app-state file with merged MCP servers (preserve other settings)
echo "$EXISTING" | jq --argjson mcp "$MCP_MERGED" '.mcpServers = $mcp' > "$CLAUDE_JSON"

echo "  -> $CLAUDE_JSON MCP servers updated"

# --- Claude Code Settings (-> <home>/settings.json) ---
# Deep-merge base + profile settings (same base+profile pattern as MCP servers
# above), then resolve placeholders. When a profile has no settings.json this is
# byte-equivalent to a plain copy of base/settings.json.

if [[ -f "$BASE_SETTINGS" ]]; then
    mkdir -p "$CLAUDE_DIR"

    SETTINGS_MERGED=$(cat "$BASE_SETTINGS")
    if [[ -f "$PROFILE_SETTINGS" ]]; then
        SETTINGS_MERGED=$(jq -s '.[0] * .[1]' "$BASE_SETTINGS" "$PROFILE_SETTINGS")
    fi

    # Variable substitution: {{CLAUDE_DIR}} first (target home), then {{HOME}}
    SETTINGS_MERGED=$(echo "$SETTINGS_MERGED" | sed -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" -e "s|{{HOME}}|$HOME|g")

    echo "$SETTINGS_MERGED" > "$CLAUDE_SETTINGS"
    echo "  -> $CLAUDE_SETTINGS updated"
fi
