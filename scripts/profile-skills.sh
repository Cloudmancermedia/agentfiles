#!/bin/bash
set -euo pipefail

# Resolve the skill set for a profile and print one skill name per line.
#   - profile has skills.txt                 -> the allowlist
#   - profile has factory-zero.flag, no list -> nothing
#   - profile has neither                    -> every skill dir under claude/skills/
# Single source of truth for "which skills does this profile get", consumed by
# the per-tool deploy scripts so Claude and Codex stay in parity.
#
# A skills.txt may inherit another profile's allowlist with an `@include <profile>`
# directive: the target's skills are emitted first, then the including profile's own
# lines add to (and can't duplicate) them. This lets `work` be `@include personal`
# plus its work extras, so a skill added to personal flows into work automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>" >&2
    exit 1
fi

SRC="$SCRIPT_DIR/claude/skills"

# Emit a manifest's skills (recursively resolving @include), deduping against
# skills already emitted this run so an inherited skill is never printed twice.
SEEN_SKILLS=()
VISITED_PROFILES=()
emit_manifest() {
    local profile="$1" p
    for p in "${VISITED_PROFILES[@]:-}"; do
        [[ "$p" == "$profile" ]] && return 0  # cycle / diamond guard
    done
    VISITED_PROFILES+=("$profile")

    local manifest="$SCRIPT_DIR/profiles/$profile/skills.txt"
    if [[ ! -f "$manifest" ]]; then
        echo "ERROR: @include target '$profile' has no skills.txt" >&2
        exit 1
    fi

    local line target s dup
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs || true)"
        [[ -n "$line" ]] || continue
        if [[ "$line" == @include* ]]; then
            target="$(echo "${line#@include}" | xargs)"
            emit_manifest "$target"
            continue
        fi
        dup=0
        for s in "${SEEN_SKILLS[@]:-}"; do
            [[ "$s" == "$line" ]] && { dup=1; break; }
        done
        [[ "$dup" -eq 1 ]] && continue
        SEEN_SKILLS+=("$line")
        echo "$line"
    done < "$manifest"
}

if [[ -f "$SCRIPT_DIR/profiles/$PROFILE/skills.txt" ]]; then
    emit_manifest "$PROFILE"
elif [[ -f "$SCRIPT_DIR/profiles/$PROFILE/factory-zero.flag" ]]; then
    : # factory-zero: no skills
else
    for d in "$SRC"/*/; do
        [[ -d "$d" ]] && basename "$d"
    done
fi
