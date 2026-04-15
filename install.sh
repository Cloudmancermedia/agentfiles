#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$SCRIPT_DIR/local"

echo "=== Claude Config Installation ==="
echo ""

# Create local directory (gitignored)
mkdir -p "$LOCAL_DIR"

# Check for existing Claude config
if [[ -f ~/.claude/CLAUDE.md ]] || [[ -f ~/.claude/settings.json ]] || [[ -f ~/.claude.json ]]; then
    BACKUP_DIR=~/.claude-backup-$(date +%Y%m%d-%H%M%S)
    echo "Existing Claude configuration detected."
    echo "Backing up to $BACKUP_DIR/"
    mkdir -p "$BACKUP_DIR"
    [[ -f ~/.claude/CLAUDE.md ]] && cp ~/.claude/CLAUDE.md "$BACKUP_DIR/"
    [[ -f ~/.claude/settings.json ]] && cp ~/.claude/settings.json "$BACKUP_DIR/"
    [[ -f ~/.claude.json ]] && cp ~/.claude.json "$BACKUP_DIR/"
    echo "Backup complete."
    echo ""
fi

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

# Save default profile
echo "$DEFAULT_PROFILE" > "$LOCAL_DIR/.current-profile"

# Apply the profile
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
