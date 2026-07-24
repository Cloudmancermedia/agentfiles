#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$SCRIPT_DIR/local"

echo "=== agentfiles Installation ==="
echo ""

mkdir -p "$LOCAL_DIR"

# Profile menu, built dynamically from profiles/*/ so it never drifts from what
# actually ships (adding a profile directory adds a menu entry automatically).
PROFILES=()
for d in "$SCRIPT_DIR"/profiles/*/; do
    [[ -d "$d" ]] && PROFILES+=("$(basename "$d")")
done
if [[ ${#PROFILES[@]} -eq 0 ]]; then
    echo "ERROR: no profiles found under $SCRIPT_DIR/profiles/" >&2
    exit 1
fi

echo "Which profile should the default home (~/.claude) use on this machine?"
i=1
for p in "${PROFILES[@]}"; do
    echo "  $i) $p"
    i=$((i + 1))
done
echo ""
read -p "Select [1-${#PROFILES[@]}]: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#PROFILES[@]} )); then
    echo "Invalid choice"; exit 1
fi
DEFAULT_PROFILE="${PROFILES[$((choice - 1))]}"

# Select which tools to configure
echo ""
echo "Which tools should be configured on this machine?"
echo "  1) Claude Code only"
echo "  2) Claude Code + Codex CLI"
echo "  3) Codex CLI only"
echo ""
read -p "Select [1/2/3]: " tool_choice
case $tool_choice in
    1) ENABLED_TOOLS="claude" ;;
    2) ENABLED_TOOLS="claude codex" ;;
    3) ENABLED_TOOLS="codex" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac
echo "$ENABLED_TOOLS" > "$LOCAL_DIR/.enabled-tools"

# Single home by default (Decision 1): bind the default home (~/.claude) to the
# chosen profile. Additional homes are a documented step — see
# docs/multi-account.md. The label "personal" names the default home, not the
# profile, matching scripts/resolve-homes.sh's convention.
{
    echo "# Which profile deploys into which Claude home."
    echo "# <label>  <profile>  <dir>   — edit to rebind; any profile may go to any home."
    printf 'personal\t%s\t~/.claude\n' "$DEFAULT_PROFILE"
} > "$LOCAL_DIR/.homes"
# A pre-existing single-home marker would otherwise trigger a migration on the
# next resolve; the freshly written .homes is authoritative, so drop it.
rm -f "$LOCAL_DIR/.current-profile"

# Deploy now, without a git pull (this is a fresh checkout).
"$SCRIPT_DIR/sync.sh" --no-pull

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Default home (~/.claude): $DEFAULT_PROFILE"
echo ""
echo "Commands:"
echo "  ./switch-profile.sh [<home>] <profile>  - Rebind a home to a profile"
echo "  ./sync.sh                               - Pull latest and reapply"
echo "  ./status.sh                             - Show homes and account state"
echo ""
echo "Add a second account/home: see docs/multi-account.md"
