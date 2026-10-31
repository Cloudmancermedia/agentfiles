#!/bin/bash
set -euo pipefail

# Codex factory-zero, the counterpart of deploy-factory-zero.sh for Claude:
#   - no AGENTS.md, no custom skills, no MCP servers, no plugins or marketplaces,
#     no hooks, no agent roles
#   - the engine settings at the top of codex/config-base.toml (model, reasoning
#     effort) are kept, so a benchmark against factory-zero changes only the
#     instructions, never the engine
#
# Only the factory-zero profile reaches here; deploy-codex.sh hands off to it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"
CODEX_DIR="$HOME/.codex"
CONFIG_BASE="$SCRIPT_DIR/codex/config-base.toml"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>" >&2
    exit 1
fi

mkdir -p "$CODEX_DIR/skills"
echo "=== Deploying Codex factory-zero... ==="

# 1. Remove custom skills, keeping Codex's own .system skills.
find "$CODEX_DIR/skills" -mindepth 1 -maxdepth 1 -type d ! -name '.system' -exec rm -rf {} +

# 2. No instructions at all.
rm -f "$CODEX_DIR/AGENTS.md"

# 3. config.toml: the top-level engine keys plus [history], nothing else. Listing
#    what to keep, rather than what to drop, stays correct when sections are
#    added to config-base later.
{
    awk '
        BEGIN { keep = 1 }
        /^\[/ { keep = ($0 == "[history]") ? 1 : 0 }
        keep { print }
    ' "$CONFIG_BASE"
    echo ""
    echo "[features]"
    echo "plugins = false"
    echo "hooks = false"
} > "$CODEX_DIR/config.toml"

# 4. No hooks.
rm -f "$CODEX_DIR/hooks.json"

echo "  -> AGENTS.md removed; config.toml stripped; hooks.json removed; skills: 0"

echo ""
echo "Codex factory-zero verification:"
FAILED=0
if grep -q '^\[mcp_servers\.' "$CODEX_DIR/config.toml"; then
    echo "  [x] config.toml still lists MCP servers"; FAILED=1
else
    echo "  [ok] no MCP servers"
fi
if grep -qE '^\[(marketplaces|plugins)\.' "$CODEX_DIR/config.toml"; then
    echo "  [x] config.toml still lists plugins or marketplaces"; FAILED=1
else
    echo "  [ok] no plugins or marketplaces"
fi
if grep -q '^\[agents' "$CODEX_DIR/config.toml"; then
    echo "  [x] agent role tables present"; FAILED=1
else
    echo "  [ok] no agent role tables"
fi
SK=$(find "$CODEX_DIR/skills" -mindepth 1 -maxdepth 1 -type d ! -name '.system' | wc -l | tr -d ' ')
if [[ "$SK" -ne 0 ]]; then
    echo "  [x] skills: $SK, expected 0"; FAILED=1
else
    echo "  [ok] skills: 0"
fi
if [[ -f "$CODEX_DIR/AGENTS.md" ]]; then
    echo "  [x] AGENTS.md present"; FAILED=1
fi

if [[ "$FAILED" -ne 0 ]]; then
    echo "CODEX FACTORY-ZERO VERIFICATION FAILED." >&2
    exit 1
fi
echo ""
echo "=== Codex factory-zero deployed and verified ==="
