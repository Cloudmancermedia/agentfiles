#!/bin/bash
set -euo pipefail

# Report Claude Code plugin enable-state for a profile and flag drift between
# what the repo declares (desired) and what is deployed in the default home
# (authoritative state = ~/.claude/settings.json enabledPlugins — the file
# Claude Code reads).
#
# Usage: verify-plugins.sh [profile]
# Informational only: prints a report and always exits 0 so it never breaks a
# sync. The report text is the signal.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"

# Default the profile to whatever is bound to the default home (~/.claude).
if [[ -z "$PROFILE" ]]; then
    while IFS=$'\t' read -r _label p dir; do
        [[ "$dir" == "$HOME/.claude" ]] && { PROFILE="$p"; break; }
    done < <("$SCRIPT_DIR/scripts/resolve-homes.sh" 2>/dev/null || true)
fi

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
INSTALLED_JSON="$HOME/.claude/plugins/installed_plugins.json"
BASE_SETTINGS="$SCRIPT_DIR/base/settings.json"
PROFILE_SETTINGS="$SCRIPT_DIR/profiles/$PROFILE/settings.json"

echo "=== Plugin state verification (profile: ${PROFILE:-unknown}) ==="

# Pure-bash membership test (avoids relying on grep, which may be aliased).
contains() { local needle="$1"; shift; local x; for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done; return 1; }

enabled_keys() { # $1 = json file -> prints enabledPlugins keys whose value is true
    [[ -f "$1" ]] || return 0
    jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$1" 2>/dev/null || true
}

# Read newline-separated lines from stdin into the named array (bash 3.2 has no
# mapfile). Usage: read_lines ARRNAME < <(cmd)
read_lines() {
    local __name="$1" __line
    eval "$__name=()"
    while IFS= read -r __line; do
        [[ -n "$__line" ]] && eval "$__name+=(\"\$__line\")"
    done
}

# --- Desired set (what the repo says SHOULD be enabled for this profile) ---
if [[ -n "$PROFILE" && -f "$SCRIPT_DIR/profiles/$PROFILE/factory-zero.flag" ]]; then
    DESIRED=()  # the teardown strips plugins and factory-zero re-adds none
    echo "Repo expects: NO enabled plugins (factory-zero profile)"
else
    read_lines DESIRED < <(enabled_keys "$BASE_SETTINGS")
    # A per-profile settings.json deep-merges over base and can add more.
    if [[ -f "$PROFILE_SETTINGS" ]]; then
        while IFS= read -r k; do contains "$k" "${DESIRED[@]:-}" || DESIRED+=("$k"); done < <(enabled_keys "$PROFILE_SETTINGS")
    fi
    echo "Repo expects enabled: ${DESIRED[*]:-(none)}"
fi

# --- Actual deployed set (authoritative: ~/.claude/settings.json) ---
read_lines ACTUAL < <(enabled_keys "$CLAUDE_SETTINGS")

# --- Installed-on-disk set ---
INSTALLED=()
if [[ -f "$INSTALLED_JSON" ]]; then
    read_lines INSTALLED < <(jq -r '.plugins // {} | keys[]' "$INSTALLED_JSON" 2>/dev/null || true)
fi

echo ""
echo "Per-plugin state (desired vs deployed-enabled):"
status_ok=1

report_one() {
    local p="$1" want="$2" have="$3" mark
    if [[ "$want" == "$have" ]]; then mark="ok"; else mark="MISMATCH"; status_ok=0; fi
    printf "  [%-8s] %s — desired=%s deployed-enabled=%s\n" "$mark" "$p" "$want" "$have"
}

# Union of installed + actually-enabled, so we catch enabled-but-not-installed too.
ALL=()
for p in "${INSTALLED[@]:-}" "${ACTUAL[@]:-}"; do [[ -n "$p" ]] && ! contains "$p" "${ALL[@]:-}" && ALL+=("$p"); done

if [[ ${#ALL[@]} -eq 0 ]]; then
    echo "  (no plugins installed or enabled)"
else
    for p in "${ALL[@]}"; do
        want=no; have=no
        contains "$p" "${DESIRED[@]:-}" && want=yes
        contains "$p" "${ACTUAL[@]:-}"  && have=yes
        report_one "$p" "$want" "$have"
    done
fi

echo ""
if [[ "$status_ok" -eq 1 ]]; then
    echo "  -> OK: deployed plugin state matches the repo's desired set for '${PROFILE:-unknown}'."
else
    echo "  -> DRIFT: deployed plugin state does not match the repo. Re-run ./sync.sh;"
    echo "     if it persists, a plugin may be pinned in a profile settings.json or enabled manually."
fi

# Supplementary live view from the CLI, when available (does not affect the verdict).
if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
    echo ""
    echo "Live 'claude plugin list' status:"
    claude plugin list 2>/dev/null | sed -n 's/^  ❯ \(.*\)$/  \1/p; s/^    Status: \(.*\)$/      status: \1/p' || true
fi

exit 0
