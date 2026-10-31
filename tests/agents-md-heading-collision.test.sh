#!/bin/bash
set -euo pipefail

# AGENTS.md is compiled from several sources: codex/instructions.md,
# base/CLAUDE.md, base/writing-rules.md, the rule files, and the profile
# appends. Nothing in that pipeline notices when two sources use the same `## `
# heading, so the file can state a rule twice with different content and Codex
# cannot tell which one wins.
#
# A tool-specific section that deliberately overrides a shared one is fine: give
# it a distinct heading and say which governs, rather than repeating the heading.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

checked=0
for profile_dir in "$ROOT_DIR"/profiles/*/; do
  profile=$(basename "$profile_dir")
  # factory-zero gets no AGENTS.md at all (deploy-codex-minimal.sh).
  [[ -f "$profile_dir/factory-zero.flag" ]] && continue

  HOME_DIR="$TMP_DIR/$profile"
  mkdir -p "$HOME_DIR"
  HOME="$HOME_DIR" "$ROOT_DIR/scripts/deploy-codex.sh" "$profile" > "$TMP_DIR/$profile.out" 2>&1 \
    || { cat "$TMP_DIR/$profile.out"; fail "deploy-codex.sh failed for profile: $profile"; }

  AGENTS="$HOME_DIR/.codex/AGENTS.md"
  [[ -f "$AGENTS" ]] || fail "AGENTS.md not generated for profile: $profile"

  DUPES=$(grep '^## ' "$AGENTS" | sort | uniq -d || true)
  if [[ -n "$DUPES" ]]; then
    echo "FAIL: duplicate '## ' headings in generated AGENTS.md ($profile):" >&2
    echo "$DUPES" | sed 's/^/  /' >&2
    echo "  Two sources compiled the same heading. Rename one and state which governs." >&2
    exit 1
  fi
  checked=$((checked + 1))
done

[[ "$checked" -gt 0 ]] || fail "no profiles were checked"

echo "PASS: no duplicate '## ' headings in generated AGENTS.md ($checked profiles)"
