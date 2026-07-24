#!/bin/bash
set -euo pipefail

# Deploy one profile into one Claude home.
#
# Composition is two layers, in order:
#   1. CORE — base/CLAUDE.md, base/rules + claude/rules, settings, and the
#      shared skill store. Unconditional: every profile gets it.
#   2. PROFILE — additions only. A profile may add to the core; it may not
#      subtract from it. If the core is wrong for a profile, the core is wrong.
#
# The deploy TEARS DOWN first (scripts/deploy-factory-zero.sh) and rebuilds.
# "Additive" describes the sources, not the filesystem operation — a rebuild is
# what guarantees a home never inherits state from the profile it last ran.
#
# `factory-zero` is the one profile that opts out of both layers: it carries
# factory-zero.flag, receives nothing, and exists as a clean baseline.
#
# Target-aware: CLAUDE_TARGET_DIR deploys into an alternate home (a
# CLAUDE_CONFIG_DIR root like ~/.claude-work); default is ~/.claude.
#
# Per-profile layers, each a no-op when the file is absent:
#   - CLAUDE.md.append   -> appended to base/CLAUDE.md
#   - rules/             -> layered over base/rules + claude/rules (name wins)
#   - skills.txt         -> the skill allowlist (@include inherits another list)
#   - mcp-servers.json   -> merged over base/mcp-servers-base.json
#   - settings.json      -> deep-merged over the core-derived settings.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"
# CLAUDE_TARGET_DIR selects an alternate Claude home (see deploy-factory-zero.sh,
# which this script runs first and which enforces the ~/.claude[-<name>] shape).
# The app-state file pairs with the home: ~/.claude.json for the default home,
# else <home>/.claude.json (where Claude Code looks when CLAUDE_CONFIG_DIR is set).
CLAUDE_DIR="${CLAUDE_TARGET_DIR:-$HOME/.claude}"
if [[ "$CLAUDE_DIR" == "$HOME/.claude" ]]; then
    CLAUDE_JSON="$HOME/.claude.json"
else
    CLAUDE_JSON="$CLAUDE_DIR/.claude.json"
fi
# Skills come from the shared deploy-time store (materialized by
# deploy-shared-skills.sh) and are laid into the home as per-skill symlinks.
SHARED_SKILLS="$HOME/.claude-shared/skills"
TARGET_DIR="$CLAUDE_DIR/skills"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
BASE_MCP="$SCRIPT_DIR/base/mcp-servers-base.json"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>" >&2
    exit 1
fi

PROFILE_DIR="$SCRIPT_DIR/profiles/$PROFILE"
if [[ ! -d "$PROFILE_DIR" ]]; then
    echo "ERROR: unknown profile '$PROFILE' (no profiles/$PROFILE)" >&2
    exit 1
fi

# factory-zero opts out of both layers: the teardown IS the whole deployment.
if [[ -f "$PROFILE_DIR/factory-zero.flag" ]]; then
    exec env CLAUDE_TARGET_DIR="$CLAUDE_DIR" "$SCRIPT_DIR/scripts/deploy-factory-zero.sh"
fi

MANIFEST="$PROFILE_DIR/skills.txt"
if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: no skills manifest at $MANIFEST" >&2
    exit 1
fi

# 1. Tear down to factory-zero, then rebuild. This empties skills/ and asserts
#    purity; if it fails, we never get to layering.
env CLAUDE_TARGET_DIR="$CLAUDE_DIR" "$SCRIPT_DIR/scripts/deploy-factory-zero.sh"

# 2. Resolve the allowlist via profile-skills.sh — the single source of truth
#    (shared with Codex) that handles comments, trimming, and @include inheritance.
SKILLS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && SKILLS+=("$line")
done < <("$SCRIPT_DIR/scripts/profile-skills.sh" "$PROFILE")

if [[ ${#SKILLS[@]} -eq 0 ]]; then
    echo "ERROR: manifest $MANIFEST lists no skills" >&2
    exit 1
fi

echo ""
echo "=== Layering core + profile ($PROFILE) ==="
if [[ ! -d "$SHARED_SKILLS" ]]; then
    echo "ERROR: shared skill store missing at $SHARED_SKILLS" >&2
    echo "       Run scripts/deploy-shared-skills.sh first (sync.sh does this automatically)." >&2
    exit 1
fi
mkdir -p "$TARGET_DIR"
for skill in "${SKILLS[@]}"; do
    if [[ ! -d "$SHARED_SKILLS/$skill" ]]; then
        echo "ERROR: skill '$skill' not in the shared store $SHARED_SKILLS (stale store? re-run deploy-shared-skills.sh)" >&2
        exit 1
    fi
    ln -sfn "$SHARED_SKILLS/$skill" "$TARGET_DIR/$skill"
    echo "  -> $skill (symlink)"
done

# 3. Optional per-profile layers.

# 3a. MCP servers — base servers plus the profile's, {{CLAUDE_DIR}}/{{HOME}}
#     resolved in the same order used everywhere.
MCP_MERGED='{}'
if [[ -f "$BASE_MCP" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$BASE_MCP")
fi
if [[ -f "$PROFILE_DIR/mcp-servers.json" ]]; then
    MCP_MERGED=$(jq -s '.[0] * .[1]' <(echo "$MCP_MERGED") "$PROFILE_DIR/mcp-servers.json")
fi
MCP_MERGED=$(echo "$MCP_MERGED" | sed -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" -e "s|{{HOME}}|$HOME|g")
if [[ -f "$CLAUDE_JSON" ]]; then
    EXISTING=$(cat "$CLAUDE_JSON")
else
    EXISTING='{}'
fi
echo "$EXISTING" | jq --argjson mcp "$MCP_MERGED" '.mcpServers = $mcp' > "$CLAUDE_JSON"
echo "  -> mcpServers layered: $(echo "$MCP_MERGED" | jq -r 'if length == 0 then "none" else (keys | join(", ")) end')"

# 3b. CLAUDE.md — the core behavioral instructions, plus the profile's additions.
#     The core is unconditional: a profile adds to it and never replaces it.
cat "$SCRIPT_DIR/base/CLAUDE.md" > "$CLAUDE_DIR/CLAUDE.md"
if [[ -f "$PROFILE_DIR/CLAUDE.md.append" ]]; then
    {
        echo ""
        echo "---"
        echo ""
        cat "$PROFILE_DIR/CLAUDE.md.append"
    } >> "$CLAUDE_DIR/CLAUDE.md"
fi
echo "  -> CLAUDE.md deployed ($(wc -c < "$CLAUDE_DIR/CLAUDE.md" | tr -d ' ') bytes)"

# 3c. Rules — core domain rules plus any the profile adds. deploy-rules.sh
#     applies the override order (base, then claude/, then profile; matching
#     filenames win later).
env CLAUDE_TARGET_DIR="$CLAUDE_DIR" "$SCRIPT_DIR/scripts/deploy-rules.sh" "$PROFILE"

# 3d. Settings overlay — deep-merge over the core-derived settings, then resolve
#     placeholders ({{CLAUDE_DIR}} first, then {{HOME}} — same order everywhere).
if [[ -f "$PROFILE_DIR/settings.json" ]]; then
    SETTINGS_MERGED=$(jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$PROFILE_DIR/settings.json" \
        | sed -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" -e "s|{{HOME}}|$HOME|g")
    echo "$SETTINGS_MERGED" > "$CLAUDE_SETTINGS"
    echo "  -> settings overlay merged: $(jq -r 'keys | join(", ")' "$PROFILE_DIR/settings.json")"
fi

# 4. Verify the final state matches the profile's manifests — no more, no less.
echo ""
echo "Verification:"
FAILED=0
# Skills are per-skill symlinks into the shared store — count links and assert
# each one resolves (a dangling link means store and allowlist are out of step).
DEPLOYED_COUNT=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | wc -l | tr -d ' ')
if [[ "$DEPLOYED_COUNT" -ne ${#SKILLS[@]} ]]; then
    echo "  [x] skills/ has $DEPLOYED_COUNT entrie(s), expected ${#SKILLS[@]}"; FAILED=1
else
    echo "  [ok] skills/ has exactly ${#SKILLS[@]} skill(s)"
fi
for skill in "${SKILLS[@]}"; do
    if [[ ! -L "$TARGET_DIR/$skill" ]]; then
        echo "  [x] skill not a symlink into the store: $skill"; FAILED=1
    elif [[ ! -d "$TARGET_DIR/$skill" ]]; then
        echo "  [x] dangling skill symlink: $skill -> $(readlink "$TARGET_DIR/$skill")"; FAILED=1
    fi
done

# MCP servers: exactly base + profile merged.
EXPECTED_MCP=$(echo "$MCP_MERGED" | jq -r 'keys | sort | join(",")')
ACTUAL_MCP=$(jq -r '.mcpServers // {} | keys | sort | join(",")' "$CLAUDE_JSON")
if [[ "$ACTUAL_MCP" != "$EXPECTED_MCP" ]]; then
    echo "  [x] mcpServers is '${ACTUAL_MCP:-<none>}', expected '${EXPECTED_MCP:-<none>}'"; FAILED=1
else
    echo "  [ok] mcpServers matches base + profile (${EXPECTED_MCP:-none})"
fi

# CLAUDE.md: core is unconditional, so it must always be present.
if [[ ! -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    echo "  [x] CLAUDE.md missing"; FAILED=1
else
    echo "  [ok] CLAUDE.md deployed"
fi

# Settings overlay: every top-level key the overlay defines must exist in the
# deployed settings.
if [[ -f "$PROFILE_DIR/settings.json" ]]; then
    for key in $(jq -r 'keys[]' "$PROFILE_DIR/settings.json"); do
        if [[ $(jq --arg k "$key" 'has($k)' "$CLAUDE_SETTINGS") != "true" ]]; then
            echo "  [x] settings overlay key '$key' missing from deployed settings"; FAILED=1
        fi
    done
    echo "  [ok] settings overlay keys present"
fi

if [[ "$FAILED" -ne 0 ]]; then
    echo "PROFILE VERIFICATION FAILED — deployed state does not match the profile manifests." >&2
    exit 1
fi

echo ""
echo "=== Profile deployed: $PROFILE (core + ${#SKILLS[@]} skill(s)) ==="
