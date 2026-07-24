#!/bin/bash
set -e

# Bind a profile to a Claude home, then deploy it there.
#
#   ./switch-profile.sh <profile>            # rebinds the default home (~/.claude)
#   ./switch-profile.sh <home> <profile>     # rebinds a named home
#
# The binding is explicit per home (local/.homes) — any profile can go to any
# home. Other homes are left alone; only the targeted one is rewritten and
# redeployed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$SCRIPT_DIR/local"
HOMES_FILE="$LOCAL_DIR/.homes"

usage() {
    echo "Usage: $0 [<home>] <profile>"
    echo ""
    echo "Profiles:"; ls -1 "$SCRIPT_DIR/profiles/" | sed 's/^/  /'
    echo ""
    echo "Homes:"
    "$SCRIPT_DIR/scripts/resolve-homes.sh" 2>/dev/null \
        | awk -F'\t' '{ printf "  %-10s %-14s %s\n", $1, $2, $3 }'
    exit 1
}

# Normalize the home table (also migrates from the pre-.homes scheme).
"$SCRIPT_DIR/scripts/resolve-homes.sh" >/dev/null

if [[ $# -eq 1 ]]; then
    HOME_LABEL=""
    PROFILE="$1"
elif [[ $# -eq 2 ]]; then
    HOME_LABEL="$1"
    PROFILE="$2"
else
    usage
fi

[[ -n "$PROFILE" && -d "$SCRIPT_DIR/profiles/$PROFILE" ]] || usage

ENABLED_TOOLS=$(cat "$LOCAL_DIR/.enabled-tools" 2>/dev/null || echo "claude")

# Resolve the target home. With no label, target whichever row is ~/.claude.
TARGET_DIR=""
TARGET_LABEL=""
CURRENT_PROFILE=""
while IFS=$'\t' read -r label profile dir; do
    if [[ -n "$HOME_LABEL" ]]; then
        [[ "$label" == "$HOME_LABEL" ]] || continue
    else
        [[ "$dir" == "$HOME/.claude" ]] || continue
    fi
    TARGET_LABEL="$label"; TARGET_DIR="$dir"; CURRENT_PROFILE="$profile"; break
done < <("$SCRIPT_DIR/scripts/resolve-homes.sh")

if [[ -z "$TARGET_DIR" ]]; then
    echo "ERROR: no home named '${HOME_LABEL:-<default>}' in local/.homes" >&2
    usage
fi

if [[ "$CURRENT_PROFILE" == "$PROFILE" ]]; then
    echo "Home '$TARGET_LABEL' is already on profile '$PROFILE'. Use ./sync.sh to reapply."
    exit 0
fi

# 1. Rebind the targeted row in .homes, leaving other rows untouched.
tmp_homes=$(mktemp)
awk -F'\t' -v label="$TARGET_LABEL" -v prof="$PROFILE" '
    /^[[:space:]]*#/ || NF == 0 { print; next }
    { if ($1 == label) { printf "%s\t%s\t%s\n", $1, prof, $3 } else { print } }
' "$HOMES_FILE" > "$tmp_homes"
mv "$tmp_homes" "$HOMES_FILE"

echo "=== Switching home '$TARGET_LABEL' ($(echo "$TARGET_DIR" | sed "s|$HOME|~|")) to profile: $PROFILE ==="
echo ""

# 2. Deploy that one home. Every profile takes the same path; deploy-profile.sh
#    short-circuits to the teardown for factory-zero.
if echo "$ENABLED_TOOLS" | grep -qw "claude"; then
    "$SCRIPT_DIR/scripts/deploy-shared-skills.sh"
    CLAUDE_TARGET_DIR="$TARGET_DIR" "$SCRIPT_DIR/scripts/deploy-profile.sh" "$PROFILE"
    "$SCRIPT_DIR/scripts/deploy-claude-plugins.sh" "$TARGET_DIR/settings.json"
fi

# 3. Codex is single-home and follows the DEFAULT home. Redeploy it only when the
#    home just switched is the default one.
if [[ "$TARGET_DIR" == "$HOME/.claude" ]] && echo "$ENABLED_TOOLS" | grep -qw "codex"; then
    echo ""
    echo "Deploying Codex configuration..."
    "$SCRIPT_DIR/scripts/deploy-codex.sh" "$PROFILE"
fi

echo ""
echo "=== Home '$TARGET_LABEL' switched to profile: $PROFILE ==="
echo ""
echo "NOTE: This only updates configuration files (CLAUDE.md, rules, MCP servers,"
echo "settings). It does NOT switch your logged-in accounts. Each home holds its"
echo "own login — see docs/multi-account.md."
