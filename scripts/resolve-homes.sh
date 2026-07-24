#!/bin/bash
set -euo pipefail

# Resolve the Claude home table: which profile deploys into which config home.
#
# Prints one `<label>\t<profile>\t<dir>` line per home, in file order. Every
# consumer (sync.sh, switch-profile.sh, status.sh) reads the table through this
# script so the binding has exactly one parser.
#
# The binding is EXPLICIT and per-home. Nothing is positional and nothing is
# implied by a profile's name — a home deploys the `work` profile because
# local/.homes says so, not because of what the profile is called. Any profile
# can be bound to any home, including adding a third home later.
#
# local/.homes format (per-machine, gitignored):
#
#     # <label>  <profile>  <dir>
#     personal    personal   ~/.claude
#     work        work       ~/.claude-work
#
#   - label   names the home (used by bin/claude-home <label>); it names the
#             HOME, not the profile, so a label may differ from its profile.
#   - profile a directory under profiles/ to deploy into this home.
#   - dir     the Claude config home; ~/.claude is the default home, additional
#             homes are ~/.claude-<name> selected via CLAUDE_CONFIG_DIR.
#
# Comments (`#`) and blank lines are ignored; columns are whitespace-separated.
#
# Migration: if .homes is absent, it is generated from the previous
# single-home scheme (.current-profile = the one profile) as a one-row table,
# and the old file is left in place but no longer read.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="$SCRIPT_DIR/local"
HOMES="$LOCAL_DIR/.homes"

# Label a home by its directory: ~/.claude is "personal" (the default home),
# ~/.claude-<name> is "<name>".
label_for_dir() {
    local t="~" dir
    dir="${1/#$HOME/$t}"
    case "$dir" in
        "~/.claude") echo "personal" ;;
        "~/.claude-"*) echo "${dir#"~/.claude-"}" ;;
        *) basename "$dir" | tr -d '.' ;;
    esac
}

migrate() {
    local current
    current=$(cat "$LOCAL_DIR/.current-profile" 2>/dev/null || true)
    [[ -n "$current" ]] || return 1

    mkdir -p "$LOCAL_DIR"
    {
        echo "# Which profile deploys into which Claude home."
        echo "# <label>  <profile>  <dir>   — edit to rebind; any profile may go to any home."
        printf '%s\t%s\t%s\n' "$(label_for_dir "$HOME/.claude")" "$current" "~/.claude"
    } > "$HOMES"
    echo "  -> migrated local/.homes from .current-profile" >&2
}

if [[ ! -f "$HOMES" ]]; then
    migrate || {
        echo "ERROR: no local/.homes and no local/.current-profile to migrate from." >&2
        echo "       Run ./install.sh first." >&2
        exit 1
    }
fi

FOUND=0
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    # Collapse runs of whitespace to a single space, then split.
    line="$(echo "$line" | xargs || true)"
    [[ -n "$line" ]] || continue
    read -r label profile dir <<< "$line"
    if [[ -z "$label" || -z "$profile" || -z "$dir" ]]; then
        echo "ERROR: malformed local/.homes line: '$line' (expected '<label> <profile> <dir>')" >&2
        exit 1
    fi
    if [[ ! -d "$SCRIPT_DIR/profiles/$profile" ]]; then
        echo "ERROR: local/.homes binds '$label' to unknown profile '$profile'" >&2
        exit 1
    fi
    printf '%s\t%s\t%s\n' "$label" "$profile" "${dir/#\~/$HOME}"
    FOUND=1
done < "$HOMES"

if [[ "$FOUND" -eq 0 ]]; then
    echo "ERROR: local/.homes lists no homes." >&2
    exit 1
fi
