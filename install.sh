#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$SCRIPT_DIR/local"

echo "=== agentfiles Installation ==="
echo ""

# Create local directory (gitignored)
mkdir -p "$LOCAL_DIR"

# Prompt for default profile
echo "Which profile should be the default for this machine?"
echo "  1) work"
echo "  2) personal"
echo ""
read -p "Select [1/2]: " choice

case $choice in
    1) DEFAULT_PROFILE="work" ;;
    2) DEFAULT_PROFILE="personal" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

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

# Apply the profile. Remove any previous marker first so reinstalling with the
# same profile still redeploys the selected tools.
rm -f "$LOCAL_DIR/.current-profile"
"$SCRIPT_DIR/switch-profile.sh" "$DEFAULT_PROFILE"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Current profile: $DEFAULT_PROFILE"
echo ""
echo "Commands:"
echo "  ./switch-profile.sh <work|personal>  - Switch profiles"
echo "  ./sync.sh                            - Pull latest and reapply"
echo "  ./status.sh                          - Show current profile"
