#!/bin/bash
set -e

SETTINGS_FILE="${1:-$HOME/.claude/settings.json}"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "  -> No Claude settings file found; plugin sync skipped"
    exit 0
fi

# The home is the settings file's directory (~/.claude, ~/.claude-work, …). The
# `claude` CLI targets it through CLAUDE_CONFIG_DIR, which the caller (sync.sh)
# sets per home; installed_plugins.json lives under that same home, not always
# the default ~/.claude.
CLAUDE_DIR="$(cd "$(dirname "$SETTINGS_FILE")" && pwd)"
INSTALLED_JSON="$CLAUDE_DIR/plugins/installed_plugins.json"

if ! command -v claude >/dev/null 2>&1 || ! claude --version >/dev/null 2>&1; then
    echo "  -> Claude Code CLI not found; plugin install/update skipped"
    exit 0
fi

echo "Syncing Claude Code plugins..."

# Add repo-managed marketplaces first so enabled plugins have a source. Official
# Claude marketplaces are available without being listed here.
while IFS= read -r marketplace; do
    source_type=$(echo "$marketplace" | jq -r '.value.source.source // empty')

    case "$source_type" in
        github)
            source_arg=$(echo "$marketplace" | jq -r '.value.source.repo')
            ;;
        git)
            source_arg=$(echo "$marketplace" | jq -r '.value.source.url')
            ;;
        directory|file)
            source_arg=$(echo "$marketplace" | jq -r '.value.source.path')
            ;;
        *)
            name=$(echo "$marketplace" | jq -r '.key')
            echo "  -> Unsupported Claude marketplace source for $name; add it manually"
            continue
            ;;
    esac

    if [[ -n "$source_arg" && "$source_arg" != "null" ]]; then
        claude plugin marketplace add "$source_arg" >/dev/null 2>&1 || true
    fi
done < <(jq -c '.extraKnownMarketplaces // {} | to_entries[]' "$SETTINGS_FILE")

# The CLI prints the failure reason on stdout, so keep it to show on failure.
if ! update_output=$(claude plugin marketplace update 2>&1); then
    echo "  -> Warning: Claude Code marketplace update failed; continuing with cached marketplaces"
    echo "$update_output" | sed 's/^/     /'
fi

while IFS= read -r plugin; do
    if jq -e --arg plugin "$plugin" '.plugins[$plugin] // empty' "$INSTALLED_JSON" >/dev/null 2>&1; then
        continue
    fi

    if claude plugin install "$plugin" --scope user >/dev/null; then
        echo "  -> Installed $plugin"
    else
        echo "  -> Warning: failed to install Claude Code plugin $plugin"
    fi
done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE")

# Update already-installed plugins to latest versions.
while IFS= read -r plugin; do
    output=$(claude plugin update "$plugin" 2>&1) || true
    if echo "$output" | grep -q "updated from"; then
        echo "  -> Updated $plugin"
    fi
done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE")

echo "  -> Claude Code plugins synced"
