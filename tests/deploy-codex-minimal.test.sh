#!/bin/bash
set -euo pipefail

# Codex factory-zero (deploy-codex-minimal.sh) strips everything that steers the
# model: AGENTS.md, custom skills, MCP servers, plugins, hooks, agent roles. It
# keeps the engine keys at the top of codex/config-base.toml, so a comparison
# against factory-zero changes only the instructions. deploy-codex.sh must route
# factory-zero here and every other profile to the full compile.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

FAKE_HOME="$TMP_DIR/home"
CODEX="$FAKE_HOME/.codex"
seed() {
  rm -rf "$FAKE_HOME"
  mkdir -p "$CODEX/skills/stale-skill" "$CODEX/skills/.system"
  printf 'SKILL\n' > "$CODEX/skills/stale-skill/SKILL.md"
  printf 'system\n' > "$CODEX/skills/.system/keep"
  printf '# old instructions\n' > "$CODEX/AGENTS.md"
  printf '{}\n' > "$CODEX/hooks.json"
  cat > "$CODEX/config.toml" <<'TOML'
model = "stale"
[mcp_servers.stale]
command = "stale"
[marketplaces.stale-market]
source_type = "git"
[plugins."stale@stale-market"]
enabled = true
[agents.stale]
config_file = "agents/stale.toml"
TOML
}

# Everything before the first [section] in config-base: the engine keys.
top_level() { awk '/^\[/ { exit } { print }' "$1"; }

assert_minimal() {
  local label="$1" cfg="$CODEX/config.toml"
  grep -q '^\[mcp_servers\.' "$cfg" && fail "$label: MCP servers remain"
  grep -qE '^\[(marketplaces|plugins)\.' "$cfg" && fail "$label: plugins or marketplaces remain"
  grep -q '^\[agents' "$cfg" && fail "$label: agent role tables remain"
  grep -qE '^[[:space:]]*(plugins|hooks)[[:space:]]*=[[:space:]]*true' "$cfg" && fail "$label: plugins or hooks feature enabled"
  grep -qE '^plugins = false$' "$cfg" || fail "$label: plugins feature not disabled"
  grep -qE '^hooks = false$' "$cfg" || fail "$label: hooks feature not disabled"
  # A TOML table may appear once; a second [features] makes the file invalid.
  [[ "$(grep -c '^\[features\]$' "$cfg")" -eq 1 ]] || fail "$label: [features] is not declared exactly once"
  # Engine keys are copied from config-base verbatim, not left from the stale file.
  [[ "$(top_level "$cfg")" == "$(top_level "$ROOT_DIR/codex/config-base.toml")" ]] \
    || fail "$label: top-level engine keys differ from codex/config-base.toml"
  grep -q 'model = "stale"' "$cfg" && fail "$label: stale engine value survived"
  if grep -q '^\[history\]$' "$ROOT_DIR/codex/config-base.toml"; then
    grep -q '^\[history\]$' "$cfg" || fail "$label: [history] was dropped"
  fi
  [[ -f "$CODEX/skills/.system/keep" ]] || fail "$label: Codex's own .system skills were clobbered"
  [[ ! -d "$CODEX/skills/stale-skill" ]] || fail "$label: stale skill not removed"
  [[ ! -f "$CODEX/hooks.json" ]] || fail "$label: hooks.json not removed"
  [[ ! -f "$CODEX/AGENTS.md" ]] || fail "$label: AGENTS.md not removed"
}

# Direct run.
seed
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-codex-minimal.sh" factory-zero > "$TMP_DIR/out" 2>&1 \
  || { cat "$TMP_DIR/out"; fail "deploy-codex-minimal.sh exited non-zero"; }
assert_minimal "direct"

# deploy-codex.sh hands factory-zero to the minimal path.
seed
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-codex.sh" factory-zero > "$TMP_DIR/out" 2>&1 \
  || { cat "$TMP_DIR/out"; fail "deploy-codex.sh factory-zero exited non-zero"; }
assert_minimal "via deploy-codex.sh"

# Every other profile takes the full compile: instructions, voice, skill index,
# and the agent role tables the minimal path strips.
for profile_dir in "$ROOT_DIR"/profiles/*/; do
  profile=$(basename "$profile_dir")
  [[ -f "$profile_dir/factory-zero.flag" ]] && continue
  seed
  HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-codex.sh" "$profile" > "$TMP_DIR/out" 2>&1 \
    || { cat "$TMP_DIR/out"; fail "deploy-codex.sh $profile exited non-zero"; }
  grep -q '^# Voice$' "$CODEX/AGENTS.md" || fail "$profile: AGENTS.md missing the Voice section"
  grep -q '^# Custom Skills$' "$CODEX/AGENTS.md" || fail "$profile: AGENTS.md missing the skill index"
  [[ -d "$CODEX/skills/stale-skill" ]] && fail "$profile: stale skill survived the full deploy"
  if grep -q '^\[agents' "$ROOT_DIR/codex/config-base.toml"; then
    grep -q '^\[agents' "$CODEX/config.toml" || fail "$profile: full deploy dropped the agent role tables"
  fi
done

echo "PASS: deploy-codex-minimal.sh strips Codex to factory-zero with engine keys kept; other profiles get the full compile"
