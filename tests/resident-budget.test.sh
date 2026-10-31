#!/bin/bash
set -euo pipefail

# Always-loaded context must stay within tests/resident-budget.txt.
#
# Resident text is paid on every session, and some of it on every turn. It grows
# back after a trim because no single commit feels large. This test makes growth
# a deliberate act: it builds each profile into a temp home, measures what Claude
# loads before you type, and fails
#   - when a bucket is over budget (trim it, or raise the budget in the same
#     commit and say why), and
#   - when a bucket is more than 5% under budget (lower the budget to lock in the
#     trim, so the next addition has to be deliberate too).
#
# Buckets, in bytes (roughly 4 bytes per token):
#   rules     CLAUDE.md + rules/*.md               every session and subagent
#   style     the active output style               main session only
#   per-turn  UserPromptSubmit hook text on "hello" every prompt
#   skills    name + description of model-invocable skills, every session
#
# Not measured, because the repo doesn't control or can't reproduce them: Claude
# Code's own system prompt, plugin skills and hooks, MCP server instructions,
# claude.ai connectors, and SessionStart hooks that print live data.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUDGET_FILE="$ROOT_DIR/tests/resident-budget.txt"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

FAKE_HOME="$TMP_DIR/home"
mkdir -p "$FAKE_HOME/.claude"
echo '{}' > "$FAKE_HOME/.claude.json"
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-shared-skills.sh" > /dev/null

# Bytes of the name and description fields in a SKILL.md frontmatter, or 0 when
# the skill is user-invoked only (Claude never sees its description).
skill_listing_bytes() {
  awk '
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/   { exit }
    in_fm && /^disable-model-invocation:[[:space:]]*true/ { hidden = 1 }
    in_fm && /^[a-z_-]+:/ { field = ($0 ~ /^(name|description):/) }
    in_fm && field { bytes += length($0) + 1 }
    END { print (hidden ? 0 : bytes + 0) }
  ' "$1"
}

measure_profile() {
  local profile="$1" claude_dir="$FAKE_HOME/.claude"
  HOME="$FAKE_HOME" CLAUDE_HOME_LABEL="$profile" \
    "$ROOT_DIR/scripts/deploy-profile.sh" "$profile" > "$TMP_DIR/deploy-$profile.log" 2>&1 \
    || { cat "$TMP_DIR/deploy-$profile.log"; fail "deploy of $profile failed"; }

  local rules style per_turn=0 skills=0 style_name hook skill_md
  rules=$(cat "$claude_dir/CLAUDE.md" "$claude_dir"/rules/*.md | wc -c | tr -d ' ')

  style_name=$(jq -r '.outputStyle // empty' "$claude_dir/settings.json")
  style=0
  [[ -n "$style_name" && -f "$claude_dir/output-styles/$style_name.md" ]] \
    && style=$(wc -c < "$claude_dir/output-styles/$style_name.md" | tr -d ' ')

  while IFS= read -r hook; do
    [[ -n "$hook" ]] || continue
    local out
    out=$(echo '{"prompt":"hello","hook_event_name":"UserPromptSubmit"}' \
      | HOME="$FAKE_HOME" bash -c "$hook" 2>/dev/null || true)
    if jq -e . >/dev/null 2>&1 <<< "$out"; then
      out=$(jq -r '.hookSpecificOutput.additionalContext // empty' <<< "$out")
    fi
    per_turn=$(( per_turn + $(printf '%s' "$out" | wc -c) ))
  done < <(jq -r '.hooks.UserPromptSubmit[]?.hooks[]?.command' "$claude_dir/settings.json")

  for skill_md in "$claude_dir"/skills/*/SKILL.md; do
    [[ -f "$skill_md" ]] || continue
    skills=$(( skills + $(skill_listing_bytes "$skill_md") ))
  done

  printf '%s rules %s\n%s style %s\n%s per-turn %s\n%s skills %s\n' \
    "$profile" "$rules" "$profile" "$style" "$profile" "$per_turn" "$profile" "$skills"
}

measured=$(for p in personal work; do measure_profile "$p"; done)

printf '%-9s %-9s %8s %8s\n' profile bucket bytes budget
status=0
while read -r profile bucket bytes; do
  budget=$(awk -v p="$profile" -v b="$bucket" '$1 == p && $2 == b { print $3 }' "$BUDGET_FILE" 2>/dev/null || true)
  printf '%-9s %-9s %8s %8s\n' "$profile" "$bucket" "$bytes" "${budget:-none}"
  if [[ -z "$budget" ]]; then
    echo "  no budget for $profile $bucket in tests/resident-budget.txt" >&2; status=1
  elif (( bytes > budget )); then
    echo "  over budget by $(( bytes - budget )) bytes: trim it, or raise the budget in this commit and say why" >&2; status=1
  elif (( bytes * 100 < budget * 95 )); then
    echo "  more than 5% under budget: lower it to $bytes to lock in the trim" >&2; status=1
  fi
done <<< "$measured"

(( status == 0 )) || fail "resident context is out of line with tests/resident-budget.txt"
echo "PASS: resident context within budget"
