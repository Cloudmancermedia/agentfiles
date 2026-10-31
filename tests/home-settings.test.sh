#!/bin/bash
set -euo pipefail

# Per-home settings overlay (homes/<label>/settings.json):
#   1. It merges LAST — its keys win over base and profile settings.
#   2. The label comes from CLAUDE_HOME_LABEL, or is derived from the home dir.
#   3. A home with no overlay file deploys unchanged.
#   4. factory-zero never receives it (the teardown short-circuits layering).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

FAKE_HOME="$TMP_DIR/home"
mkdir -p "$FAKE_HOME/.claude"
echo '{}' > "$FAKE_HOME/.claude.json"

HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-shared-skills.sh" > /dev/null

# 1+2. Explicit label: deploy personal with the 'personal' home overlay.
[[ -f "$ROOT_DIR/homes/personal/settings.json" ]] || fail "homes/personal/settings.json missing from repo"
HOME="$FAKE_HOME" CLAUDE_HOME_LABEL="personal" \
  "$ROOT_DIR/scripts/deploy-profile.sh" personal > "$TMP_DIR/out" 2>&1 \
  || { cat "$TMP_DIR/out"; fail "deploy with home overlay exited non-zero"; }

for key in $(jq -r 'keys[]' "$ROOT_DIR/homes/personal/settings.json"); do
  expected=$(jq --arg k "$key" '.[$k]' "$ROOT_DIR/homes/personal/settings.json")
  actual=$(jq --arg k "$key" '.[$k]' "$FAKE_HOME/.claude/settings.json")
  [[ "$actual" == "$expected" ]] \
    || fail "home overlay key '$key' is $actual, expected $expected (overlay must win)"
done
grep -q "home settings overlay merged (personal)" "$TMP_DIR/out" \
  || fail "deploy output does not report the home overlay merge"

# The overlay must override base: any key present in BOTH must show the home value.
for key in $(jq -r 'keys[]' "$ROOT_DIR/homes/personal/settings.json"); do
  if [[ $(jq --arg k "$key" 'has($k)' "$ROOT_DIR/base/settings.json") == "true" ]]; then
    base_val=$(jq --arg k "$key" '.[$k]' "$ROOT_DIR/base/settings.json")
    home_val=$(jq --arg k "$key" '.[$k]' "$ROOT_DIR/homes/personal/settings.json")
    if [[ "$base_val" != "$home_val" ]]; then
      actual=$(jq --arg k "$key" '.[$k]' "$FAKE_HOME/.claude/settings.json")
      [[ "$actual" == "$home_val" ]] || fail "base value for '$key' survived over the home overlay"
    fi
  fi
done

# 2b. Derived label: no CLAUDE_HOME_LABEL, default home dir -> 'personal'.
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-profile.sh" personal > "$TMP_DIR/out-derived" 2>&1 \
  || { cat "$TMP_DIR/out-derived"; fail "deploy with derived label exited non-zero"; }
grep -q "home settings overlay merged (personal)" "$TMP_DIR/out-derived" \
  || fail "label was not derived from the default home dir"

# 3. Unknown label -> no overlay file -> no merge, still succeeds.
HOME="$FAKE_HOME" CLAUDE_HOME_LABEL="no-such-home" \
  "$ROOT_DIR/scripts/deploy-profile.sh" personal > "$TMP_DIR/out-none" 2>&1 \
  || { cat "$TMP_DIR/out-none"; fail "deploy without overlay exited non-zero"; }
grep -q "home settings overlay merged" "$TMP_DIR/out-none" \
  && fail "overlay merged for a home with no settings file"
model_now=$(jq -r '.model // empty' "$FAKE_HOME/.claude/settings.json")
model_base=$(jq -r '.model // empty' "$ROOT_DIR/base/settings.json")
[[ "$model_now" == "$model_base" ]] \
  || fail "without an overlay, model should be base's ($model_base), got '$model_now'"

# 4. factory-zero: the home overlay must NOT reach it.
HOME="$FAKE_HOME" CLAUDE_HOME_LABEL="personal" \
  "$ROOT_DIR/scripts/deploy-profile.sh" factory-zero > "$TMP_DIR/out-fz" 2>&1 \
  || { cat "$TMP_DIR/out-fz"; fail "factory-zero deploy exited non-zero"; }
grep -q "home settings overlay merged" "$TMP_DIR/out-fz" \
  && fail "home overlay reached factory-zero"
fz_model=$(jq -r '.model // empty' "$FAKE_HOME/.claude/settings.json")
[[ "$fz_model" == "$model_base" ]] \
  || fail "factory-zero model should stay base's engine value ($model_base), got '$fz_model'"

# 5. Effort is set per model. A top-level effortLevel in a user settings file
#    doesn't apply to Opus 5.5 (code.claude.com/docs/en/model-config#adjust-effort-level),
#    so a home must declare its model's level under modelSettings, keyed by the
#    canonical name (no [1m] suffix). Sync rewrites settings.json, so a level saved
#    with /effort alone is lost on the next sync.
for overlay in "$ROOT_DIR"/homes/*/settings.json; do
  label=$(basename "$(dirname "$overlay")")
  jq -e 'has("effortLevel")' "$overlay" >/dev/null \
    && fail "homes/$label sets a top-level effortLevel, which Opus 5.5 ignores; use modelSettings.<model>.effortLevel"
  model=$(jq -r '.model // empty' "$overlay")
  [[ -n "$model" ]] || continue
  canonical="${model%%\[*}"
  jq -e --arg m "$canonical" '.modelSettings[$m].effortLevel // empty' "$overlay" >/dev/null \
    || fail "homes/$label runs $model but sets no modelSettings.\"$canonical\".effortLevel"
done

echo "PASS: home settings overlay merges last, keys win, factory-zero exempt"
