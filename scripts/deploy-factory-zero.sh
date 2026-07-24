#!/bin/bash
set -euo pipefail

# Tear a Claude home down to factory-zero: no CLAUDE.md, no rules, no custom
# skills, no output styles, no MCP servers, no enabled plugins. This is two
# things at once:
#   1. The teardown primitive every profile deploy runs first, so a home never
#      inherits state from the profile it last ran (deploy-profile.sh calls this,
#      then layers the profile on top).
#   2. A shippable example profile (profiles/factory-zero/) that stops here —
#      a home with agentfiles installed but nothing steering the model, useful as
#      a clean baseline to compare a profile against.
#
# See docs/customization.md for the profile/home model.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_SETTINGS="$SCRIPT_DIR/base/settings.json"
# CLAUDE_TARGET_DIR selects an alternate Claude home (a CLAUDE_CONFIG_DIR root,
# e.g. ~/.claude-work for a second-account home). Default is the primary
# ~/.claude. When targeting an alternate home, the app-state file lives INSIDE
# it (that is where Claude Code looks when CLAUDE_CONFIG_DIR is set); only the
# primary home pairs with ~/.claude.json.
CLAUDE_DIR="${CLAUDE_TARGET_DIR:-$HOME/.claude}"
if [[ "$CLAUDE_DIR" == "$HOME/.claude" ]]; then
    CLAUDE_JSON="$HOME/.claude.json"
else
    CLAUDE_JSON="$CLAUDE_DIR/.claude.json"
fi

# Safety: the rm -rf calls below must only ever run against a real Claude home
# directly under a non-empty $HOME — ~/.claude or ~/.claude-<name>, nothing else.
if [[ -z "${HOME:-}" ]]; then
    echo "ERROR: refusing to run — \$HOME is empty" >&2
    exit 1
fi
case "$CLAUDE_DIR" in
    "$HOME/.claude"|"$HOME/.claude-"?*) ;;
    *)
        echo "ERROR: refusing to run — CLAUDE_DIR is unexpected ('$CLAUDE_DIR')" >&2
        exit 1
        ;;
esac

echo "=== Tearing down to factory-zero (Claude) [$CLAUDE_DIR] ==="

# 1. Remove user CLAUDE.md entirely.
rm -f "$CLAUDE_DIR/CLAUDE.md"

# 2. Empty rules.
rm -rf "$CLAUDE_DIR/rules"
mkdir -p "$CLAUDE_DIR/rules"

# 3. Empty custom skills.
rm -rf "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/skills"

# 4. Empty output styles (the dir is entirely ours to manage; profiles that use
#    an output style re-deploy it).
rm -rf "$CLAUDE_DIR/output-styles"
mkdir -p "$CLAUDE_DIR/output-styles"

# 5. Hooks: intentionally untouched. They are inert at baseline (no `hooks` key in
#    settings, plugins disabled), and deleting the dir risks collateral damage to
#    plugin-managed hook files.

# 6. Clear MCP servers but preserve every other key in .claude.json (e.g. the
#    per-project local scope Claude Code stores there).
if [[ -f "$CLAUDE_JSON" ]]; then
    UPDATED=$(jq '.mcpServers = {}' "$CLAUDE_JSON")
    echo "$UPDATED" > "$CLAUDE_JSON"
else
    echo '{"mcpServers": {}}' > "$CLAUDE_JSON"
fi

# 7. Derive settings.json from base/settings.json with the profile-layer keys
#    stripped: empty enabledPlugins/marketplaces leave installed plugins inert
#    without uninstalling them; .statusLine and .outputStyle are re-layered by
#    profiles that opt in. The sed resolves the same placeholders every other
#    deploy step uses ({{CLAUDE_DIR}} first, then {{HOME}}).
mkdir -p "$CLAUDE_DIR"
jq 'del(.enabledPlugins, .extraKnownMarketplaces, .statusLine, .outputStyle)' "$BASE_SETTINGS" \
    | sed -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" -e "s|{{HOME}}|$HOME|g" > "$CLAUDE_DIR/settings.json"

echo "  -> CLAUDE.md removed; rules/ + skills/ + output-styles/ emptied; mcpServers cleared; plugins disabled"

# 8. Verify. Any failure exits non-zero.
echo ""
echo "Baseline verification:"
FAILED=0

if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then echo "  [x] CLAUDE.md still present"; FAILED=1; else echo "  [ok] CLAUDE.md absent"; fi

RULES_COUNT=$(find "$CLAUDE_DIR/rules" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$RULES_COUNT" -ne 0 ]]; then echo "  [x] rules/ has $RULES_COUNT files"; FAILED=1; else echo "  [ok] rules/ empty"; fi

SKILLS_COUNT=$(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SKILLS_COUNT" -ne 0 ]]; then echo "  [x] skills/ has $SKILLS_COUNT entries"; FAILED=1; else echo "  [ok] skills/ empty"; fi

STYLES_COUNT=$(find "$CLAUDE_DIR/output-styles" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STYLES_COUNT" -ne 0 ]]; then echo "  [x] output-styles/ has $STYLES_COUNT files"; FAILED=1; else echo "  [ok] output-styles/ empty"; fi

OUTPUT_STYLE=$(jq -r '.outputStyle // "none"' "$CLAUDE_DIR/settings.json")
if [[ "$OUTPUT_STYLE" != "none" ]]; then echo "  [x] outputStyle set to '$OUTPUT_STYLE' (should be unset at factory-zero)"; FAILED=1; else echo "  [ok] outputStyle unset (default voice)"; fi

MCP_COUNT=$(jq -r '.mcpServers // {} | length' "$CLAUDE_JSON")
if [[ "$MCP_COUNT" -ne 0 ]]; then echo "  [x] mcpServers has $MCP_COUNT"; FAILED=1; else echo "  [ok] mcpServers empty"; fi

PLUGIN_COUNT=$(jq -r '.enabledPlugins // {} | length' "$CLAUDE_DIR/settings.json")
if [[ "$PLUGIN_COUNT" -ne 0 ]]; then echo "  [x] enabledPlugins has $PLUGIN_COUNT"; FAILED=1; else echo "  [ok] no enabled plugins"; fi

if [[ "$FAILED" -ne 0 ]]; then
    echo "BASELINE VERIFICATION FAILED — state is not factory-zero." >&2
    exit 1
fi

echo ""
echo "=== Factory-zero verified ==="
