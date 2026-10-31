#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

CODEX_DIR=~/.codex
mkdir -p "$CODEX_DIR"

# factory-zero gets a stripped Codex: no AGENTS.md, skills, MCP servers, plugins,
# hooks, or agent roles. Every other profile takes the full compile below.
if [[ -f "$SCRIPT_DIR/profiles/$PROFILE/factory-zero.flag" ]]; then
    exec "$SCRIPT_DIR/scripts/deploy-codex-minimal.sh" "$PROFILE"
fi

echo "Deploying Codex configuration (profile: $PROFILE)..."

# 1. Deploy custom skills so AGENTS.md can reference installed skill metadata
"$SCRIPT_DIR/scripts/deploy-skills.sh" codex "$PROFILE"

# 1b. Subagent role layers. The [agents.*] tables in config.toml name them with
# paths like "agents/explorer.toml", which resolve relative to config.toml, so
# they live in ~/.codex/agents/. Only our files are refreshed; roles you add
# there by hand are left alone.
AGENTS_SRC="$SCRIPT_DIR/codex/agents"
if [[ -d "$AGENTS_SRC" ]]; then
    mkdir -p "$CODEX_DIR/agents"
    for f in "$AGENTS_SRC"/*.toml; do
        [[ -f "$f" ]] || continue
        cp "$f" "$CODEX_DIR/agents/$(basename "$f")"
    done
    echo "  -> $CODEX_DIR/agents/ updated ($(find "$AGENTS_SRC" -maxdepth 1 -name '*.toml' | wc -l | tr -d ' ') role layers)"
fi

# 2. Compile AGENTS.md from components
"$SCRIPT_DIR/scripts/compile-agents-md.sh" "$PROFILE" "$CODEX_DIR/AGENTS.md"

# 3. Merge MCP server JSON (base + profile), apply {{HOME}} substitution
BASE_MCP="$SCRIPT_DIR/base/mcp-servers-base.json"
PROFILE_MCP="$SCRIPT_DIR/profiles/$PROFILE/mcp-servers.json"

MCP_MERGED='{}'
if [[ -f "$BASE_MCP" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$BASE_MCP")
fi
if [[ -f "$PROFILE_MCP" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$PROFILE_MCP")
fi
MCP_MERGED=$(echo "$MCP_MERGED" | sed "s|{{HOME}}|$HOME|g")

# 4. Convert MCP JSON to TOML
MCP_TOML=$(echo "$MCP_MERGED" | "$SCRIPT_DIR/scripts/json-to-toml-mcp.sh")

# 5. Assemble config.toml: base settings + MCP servers
{
    if [[ -f "$SCRIPT_DIR/codex/config-base.toml" ]]; then
        cat "$SCRIPT_DIR/codex/config-base.toml"
        echo ""
    fi
    echo "$MCP_TOML"
} > "$CODEX_DIR/config.toml"

echo "  -> $CODEX_DIR/config.toml updated"

# 6. Refresh configured plugin marketplaces. Codex stores desired marketplace
# and plugin enablement in config.toml, then installs plugin bundles into its
# cache from those configured marketplaces. The template does not enable any
# marketplaces by default; this only runs after users add their own.
if grep -q '^\[marketplaces\.' "$CODEX_DIR/config.toml"; then
    echo "Refreshing Codex plugin marketplaces..."
    CODEX_HOME="$CODEX_DIR" codex plugin marketplace upgrade
    echo "  -> Codex plugin marketplaces refreshed"
fi

echo "  Codex deployment complete."
