#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Flags:
#   --verify   after deploying, print a plugin enable-state report for the
#              default home so plugin drift is visibly confirmed.
#   --no-pull  skip the git pull (install.sh uses this to deploy a fresh clone).
VERIFY=0
PULL=1
for arg in "$@"; do
    case "$arg" in
        --verify) VERIFY=1 ;;
        --no-pull) PULL=0 ;;
        *) echo "Unknown option: $arg (supported: --verify, --no-pull)" >&2; exit 1 ;;
    esac
done

ENABLED_TOOLS=$(cat "$SCRIPT_DIR/local/.enabled-tools" 2>/dev/null || echo "claude")

# Which profile deploys into which Claude home. The binding is explicit per home
# (see scripts/resolve-homes.sh) — any profile can go to any home, so nothing
# below assumes a home's profile from its name or position.
HOME_ROWS=()
while IFS= read -r row; do
    [[ -n "$row" ]] && HOME_ROWS+=("$row")
done < <("$SCRIPT_DIR/scripts/resolve-homes.sh")

# The default home's profile is what Codex falls back to.
DEFAULT_PROFILE=""
for row in "${HOME_ROWS[@]}"; do
    IFS=$'\t' read -r _label row_profile row_dir <<< "$row"
    if [[ "$row_dir" == "$HOME/.claude" ]]; then DEFAULT_PROFILE="$row_profile"; break; fi
done
[[ -n "$DEFAULT_PROFILE" ]] || DEFAULT_PROFILE=$(IFS=$'\t'; set -- ${HOME_ROWS[0]}; echo "$2")

# Shorten $HOME back to ~ for display.
tilde() { local t="~"; echo "${1/#$HOME/$t}"; }

# One line per <tool, profile, destination> triple — printed before the work as
# the plan and after it as the receipt.
print_deployment_map() {
    if echo "$ENABLED_TOOLS" | grep -qw "claude"; then
        for row in "${HOME_ROWS[@]}"; do
            IFS=$'\t' read -r row_label row_profile row_dir <<< "$row"
            printf '  Claude   %-14s -> %s (%s)\n' "$row_profile" "$(tilde "$row_dir")" "$row_label"
        done
    fi
    if echo "$ENABLED_TOOLS" | grep -qw "codex"; then
        printf '  Codex    %-14s -> %s\n' "$DEFAULT_PROFILE" "$(tilde ~/.codex)"
    fi
}

echo "=== Syncing agentfiles ==="
echo "Deploying:"
print_deployment_map
echo ""

# Pull latest
if [[ "$PULL" -eq 1 ]]; then
    echo "Pulling latest changes..."
    cd "$SCRIPT_DIR"
    git pull --ff-only || {
        echo ""
        echo "Warning: Could not fast-forward. You may have local changes."
        echo "Run 'git status' to check, then 'git pull --rebase' if needed."
        exit 1
    }
fi

echo ""
echo "Reapplying configuration..."

# Deploy Claude Code configuration (if enabled)
if echo "$ENABLED_TOOLS" | grep -qw "claude"; then
    # Shared skill store first — homes lay their skills as symlinks into it.
    "$SCRIPT_DIR/scripts/deploy-shared-skills.sh"

    # Every home is deployed the same way: one profile, one CLAUDE_TARGET_DIR.
    # There is no "primary" special case — the default home is just the row
    # whose dir is ~/.claude.
    for row in "${HOME_ROWS[@]}"; do
        IFS=$'\t' read -r row_label row_profile row_dir <<< "$row"
        echo ""
        echo "--- Claude [$row_label]: $row_profile -> $(tilde "$row_dir") ---"
        CLAUDE_TARGET_DIR="$row_dir" "$SCRIPT_DIR/scripts/deploy-profile.sh" "$row_profile"
        # Plugins: installation is machine-global, enable-state is per home, so
        # sync each home against its own settings.json.
        "$SCRIPT_DIR/scripts/deploy-claude-plugins.sh" "$row_dir/settings.json"
    done

    if [[ "$VERIFY" -eq 1 ]]; then
        echo ""
        "$SCRIPT_DIR/scripts/verify-plugins.sh" "$DEFAULT_PROFILE"
    fi
fi

# Deploy Codex configuration (if enabled). Codex is single-home and follows the
# default home's profile.
if echo "$ENABLED_TOOLS" | grep -qw "codex"; then
    echo ""
    echo "--- Codex: $DEFAULT_PROFILE -> $(tilde ~/.codex) ---"
    "$SCRIPT_DIR/scripts/deploy-codex.sh" "$DEFAULT_PROFILE"
fi

# Record sync time
echo "$(date +%Y-%m-%d)" > "$SCRIPT_DIR/local/.last-sync"

echo ""
echo "=== Sync complete ==="
echo "Deployed:"
print_deployment_map
