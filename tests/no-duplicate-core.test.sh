#!/bin/bash
set -euo pipefail

# The writing rules live once, in base/writing-rules.md, and reach each tool by
# deploy: rules/writing-rules.md in every Claude home, the "Voice" section of
# Codex's AGENTS.md, and only a pointer in the example output style. A second
# hand-maintained copy drifts from the first, and the model then sees two
# versions of one rule. This guards that the source has one copy and that each
# destination receives it exactly once.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

CANON="$ROOT_DIR/base/writing-rules.md"
[[ -f "$CANON" ]] || fail "base/writing-rules.md missing"

# The rule lines themselves (bullets), which are what a copy would repeat.
RULE_LINES=()
while IFS= read -r line; do
  RULE_LINES+=("$line")
done < <(grep -E '^- .{20,}' "$CANON")
[[ ${#RULE_LINES[@]} -gt 0 ]] || fail "no rule lines found in base/writing-rules.md"

# Count how many lines of a file equal a given rule line.
count_in() { grep -Fxc -- "$1" "$2" || true; }

# --- Source: no other file carries a rule line ------------------------------
# A copy under a rules/ dir would also be compiled into AGENTS.md a second time.
SOURCE_DIRS=("$ROOT_DIR/base" "$ROOT_DIR/profiles" "$ROOT_DIR/codex")
[[ -d "$ROOT_DIR/claude/rules" ]] && SOURCE_DIRS+=("$ROOT_DIR/claude/rules")
while IFS= read -r f; do
  [[ "$f" == "$CANON" ]] && continue
  for rule in "${RULE_LINES[@]}"; do
    [[ "$(count_in "$rule" "$f")" -eq 0 ]] \
      || fail "${f#"$ROOT_DIR"/} restates a writing rule: \"$rule\"; point at writing-rules.md instead"
  done
done < <(find "${SOURCE_DIRS[@]}" -type f \( -name '*.md' -o -name '*.append' \))

# --- Claude: rules/ has it once, the style only points at it ----------------
FAKE_HOME="$TMP_DIR/home"
mkdir -p "$FAKE_HOME/.claude"
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-shared-skills.sh" > /dev/null
for profile_dir in "$ROOT_DIR"/profiles/*/; do
  profile=$(basename "$profile_dir")
  [[ -f "$profile_dir/factory-zero.flag" ]] && continue
  HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-profile.sh" "$profile" > "$TMP_DIR/out" 2>&1 \
    || { cat "$TMP_DIR/out"; fail "deploy-profile.sh $profile failed"; }
  CD="$FAKE_HOME/.claude"
  cmp -s "$CANON" "$CD/rules/writing-rules.md" || fail "$profile: rules/writing-rules.md differs from the source"
  for rule in "${RULE_LINES[@]}"; do
    total=0
    for f in "$CD"/rules/*.md "$CD"/output-styles/*.md "$CD/CLAUDE.md"; do
      [[ -f "$f" ]] || continue
      total=$((total + $(count_in "$rule" "$f")))
    done
    [[ "$total" -eq 1 ]] || fail "$profile: writing rule appears $total times across the Claude home: \"$rule\""
  done
done

# --- Codex: AGENTS.md has it once -------------------------------------------
for profile_dir in "$ROOT_DIR"/profiles/*/; do
  profile=$(basename "$profile_dir")
  [[ -f "$profile_dir/factory-zero.flag" ]] && continue
  OUT="$TMP_DIR/AGENTS-$profile.md"
  HOME="$FAKE_HOME" "$ROOT_DIR/scripts/compile-agents-md.sh" "$profile" "$OUT" > /dev/null
  [[ "$(grep -c '^# Voice$' "$OUT")" -eq 1 ]] || fail "$profile: AGENTS.md does not have exactly one Voice section"
  for rule in "${RULE_LINES[@]}"; do
    n=$(count_in "$rule" "$OUT")
    [[ "$n" -eq 1 ]] || fail "$profile: AGENTS.md carries a writing rule $n times: \"$rule\""
  done
done

echo "PASS: writing rules have one source and reach rules/ and AGENTS.md exactly once"
