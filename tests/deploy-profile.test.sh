#!/bin/bash
set -euo pipefail

# deploy-profile.sh tears a home down to factory-zero, then layers core + profile.
#
# Scenario 1 runs against the real repo: a home seeded with stale state from some
# earlier profile must end up with exactly the core plus the personal profile,
# and nothing left over.
#
# Scenario 2 runs against a throwaway copy with fixtures, because the shipped
# profiles leave most optional layers empty (no MCP servers, no plugins, no
# profile settings). Without fixtures the merge logic is never exercised.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Sorted, comma-joined basenames of the *.md files in the given dirs (missing
# dirs are skipped), de-duplicated the way a later cp overwrites an earlier one.
md_names() {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] && find "$d" -maxdepth 1 -name '*.md' -exec basename {} \;
  done | sort -u | paste -sd, -
}

check_skills() {
  local home="$1" claude_dir="$2" repo="$3" profile="$4"
  local expected=() line count skill link
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && expected+=("$line")
  done < <("$repo/scripts/profile-skills.sh" "$profile")
  count=$(find "$claude_dir/skills" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | wc -l | tr -d ' ')
  [[ "$count" -eq ${#expected[@]} ]] \
    || fail "$profile: skills/ has $count entries, expected ${#expected[@]}"
  for skill in "${expected[@]}"; do
    link="$claude_dir/skills/$skill"
    [[ -L "$link" ]] || fail "$profile: skill missing or not a symlink: $skill"
    [[ -d "$link" ]] || fail "$profile: dangling skill symlink: $skill"
    [[ "$(readlink "$link")" == "$home/.claude-shared/skills/$skill" ]] \
      || fail "$profile: skill '$skill' links outside the shared store: $(readlink "$link")"
  done
}

# --- Scenario 1: personal, real repo, stale seeded home ----------------------

FAKE_HOME="$TMP_DIR/home"
CD="$FAKE_HOME/.claude"
mkdir -p "$CD/rules" "$CD/skills/stale-skill" "$CD/output-styles"
printf '# stale instructions\n' > "$CD/CLAUDE.md"
printf '# stale rule\n' > "$CD/rules/stale-rule.md"
printf 'SKILL\n' > "$CD/skills/stale-skill/SKILL.md"
printf '# stale style\n' > "$CD/output-styles/stale-style.md"
cat > "$CD/settings.json" <<'JSON'
{ "enabledPlugins": { "stale-plugin@stale-market": true }, "outputStyle": "stale-style" }
JSON
cat > "$FAKE_HOME/.claude.json" <<'JSON'
{ "mcpServers": { "stale-server": { "command": "x" } },
  "projects": { "/some/dir": { "allowedTools": [] } } }
JSON

HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-shared-skills.sh" > /dev/null
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-profile.sh" personal > "$TMP_DIR/out1" 2>&1 \
  || { cat "$TMP_DIR/out1"; fail "personal deploy exited non-zero"; }

# CLAUDE.md is the core followed by the profile append, never one without the other.
{
  cat "$ROOT_DIR/base/CLAUDE.md"
  printf '\n---\n\n'
  cat "$ROOT_DIR/profiles/personal/CLAUDE.md.append"
} > "$TMP_DIR/expected-claude.md"
cmp -s "$TMP_DIR/expected-claude.md" "$CD/CLAUDE.md" \
  || fail "deployed CLAUDE.md is not base/CLAUDE.md + the personal append"

# Rules: base + claude + profile rules, plus writing-rules.md from base/. The
# stale rule from the previous profile must be gone.
EXPECTED_RULES=$( { md_names "$ROOT_DIR/base/rules" "$ROOT_DIR/claude/rules" "$ROOT_DIR/profiles/personal/rules" | tr ',' '\n'; echo writing-rules.md; } | sort -u | paste -sd, -)
ACTUAL_RULES=$(md_names "$CD/rules")
[[ "$ACTUAL_RULES" == "$EXPECTED_RULES" ]] \
  || fail "rules/ is '$ACTUAL_RULES', expected '$EXPECTED_RULES'"

# MCP: exactly base + profile (both empty as shipped), stale server cleared,
# other .claude.json keys preserved.
EXPECTED_MCP=$(jq -s '.[0] * .[1] | keys | sort | join(",")' "$ROOT_DIR/base/mcp-servers-base.json" "$ROOT_DIR/profiles/personal/mcp-servers.json")
ACTUAL_MCP=$(jq '.mcpServers | keys | sort | join(",")' "$FAKE_HOME/.claude.json")
[[ "$ACTUAL_MCP" == "$EXPECTED_MCP" ]] || fail "mcpServers is $ACTUAL_MCP, expected $EXPECTED_MCP"
jq -e '.projects["/some/dir"]' "$FAKE_HOME/.claude.json" >/dev/null \
  || fail ".claude.json lost its projects key"

# Plugins: exactly base's set; the seeded stale plugin is gone.
EXPECTED_PLUGINS=$(jq -r '.enabledPlugins // {} | keys | sort | join(",")' "$ROOT_DIR/base/settings.json")
ACTUAL_PLUGINS=$(jq -r '.enabledPlugins // {} | keys | sort | join(",")' "$CD/settings.json")
[[ "$ACTUAL_PLUGINS" == "$EXPECTED_PLUGINS" ]] \
  || fail "enabledPlugins is '$ACTUAL_PLUGINS', expected base's '$EXPECTED_PLUGINS'"

# Skills: exactly the allowlist, as symlinks into the shared store.
[[ ! -e "$CD/skills/stale-skill" ]] || fail "stale skill survived"
check_skills "$FAKE_HOME" "$CD" "$ROOT_DIR" personal

# Output styles: the shared styles are back, the stale one and its selection gone.
[[ ! -e "$CD/output-styles/stale-style.md" ]] || fail "stale output style survived"
for style in "$ROOT_DIR"/base/output-styles/*.md; do
  [[ -f "$CD/output-styles/$(basename "$style")" ]] || fail "output style $(basename "$style") not deployed"
done
jq -e 'has("outputStyle") | not' "$CD/settings.json" >/dev/null \
  || fail "stale outputStyle selection survived"

# --- Scenario 2: work in a fixture copy, every optional layer populated -------

REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"

# Base and profile both declare MCP servers, overlapping on shared-srv, so the
# merge (agentfiles merges base into every home) and its precedence are visible.
cat > "$REPO/base/mcp-servers-base.json" <<'JSON'
{ "base-srv": { "command": "base-cmd" }, "shared-srv": { "command": "from-base" } }
JSON
cat > "$REPO/profiles/work/mcp-servers.json" <<'JSON'
{ "work-srv": { "command": "{{HOME}}/bin/work-cmd" }, "shared-srv": { "command": "from-work" } }
JSON
# Base declares a plugin; the teardown strips it and the deploy must re-add it.
jq '.enabledPlugins = {"base-plugin@example-market": true}
    | .extraKnownMarketplaces = {"example-market": {"source": {"source": "github", "repo": "your-org/your-repo"}}}' \
  "$ROOT_DIR/base/settings.json" > "$REPO/base/settings.json"
# The profile overlay adds its own plugin and a placeholder-bearing key.
cat > "$REPO/profiles/work/settings.json" <<'JSON'
{ "enabledPlugins": { "work-plugin@example-market": true },
  "env": { "FIXTURE_DIR": "{{CLAUDE_DIR}}/fixture" } }
JSON
# A profile rule with the same name as a base rule must win.
printf '# work override\n' > "$REPO/profiles/work/rules/documentation.md"

FAKE_HOME2="$TMP_DIR/home2"
CD2="$FAKE_HOME2/.claude"
mkdir -p "$CD2"
HOME="$FAKE_HOME2" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null
HOME="$FAKE_HOME2" "$REPO/scripts/deploy-profile.sh" work > "$TMP_DIR/out2" 2>&1 \
  || { cat "$TMP_DIR/out2"; fail "work fixture deploy exited non-zero"; }

[[ "$(jq -r '.mcpServers | keys | sort | join(",")' "$FAKE_HOME2/.claude.json")" == "base-srv,shared-srv,work-srv" ]] \
  || fail "work mcpServers is $(jq -c '.mcpServers | keys' "$FAKE_HOME2/.claude.json"), expected base + profile"
[[ "$(jq -r '.mcpServers["shared-srv"].command' "$FAKE_HOME2/.claude.json")" == "from-work" ]] \
  || fail "profile MCP entry did not override base's on a shared name"
[[ "$(jq -r '.mcpServers["work-srv"].command' "$FAKE_HOME2/.claude.json")" == "$FAKE_HOME2/bin/work-cmd" ]] \
  || fail "{{HOME}} not resolved in a profile MCP server"

[[ "$(jq -r '.enabledPlugins | keys | sort | join(",")' "$CD2/settings.json")" == "base-plugin@example-market,work-plugin@example-market" ]] \
  || fail "enabledPlugins is $(jq -c '.enabledPlugins' "$CD2/settings.json"), expected base + profile union"
jq -e '.extraKnownMarketplaces["example-market"]' "$CD2/settings.json" >/dev/null \
  || fail "base marketplace was not re-layered after the teardown"
[[ "$(jq -r '.env.FIXTURE_DIR' "$CD2/settings.json")" == "$CD2/fixture" ]] \
  || fail "{{CLAUDE_DIR}} not resolved in the profile settings overlay"

grep -Fq "$(grep -m1 '^# ' "$REPO/profiles/work/CLAUDE.md.append")" "$CD2/CLAUDE.md" \
  || fail "work CLAUDE.md is missing the work append"
[[ "$(cat "$CD2/rules/documentation.md")" == "# work override" ]] \
  || fail "profile rule did not override the base rule of the same name"
check_skills "$FAKE_HOME2" "$CD2" "$REPO" work

# Base's servers reach a profile that declares none of its own.
FAKE_HOME3="$TMP_DIR/home3"
mkdir -p "$FAKE_HOME3/.claude"
HOME="$FAKE_HOME3" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null
HOME="$FAKE_HOME3" "$REPO/scripts/deploy-profile.sh" personal > "$TMP_DIR/out3" 2>&1 \
  || { cat "$TMP_DIR/out3"; fail "personal fixture deploy exited non-zero"; }
[[ "$(jq -r '.mcpServers | keys | sort | join(",")' "$FAKE_HOME3/.claude.json")" == "base-srv,shared-srv" ]] \
  || fail "personal did not receive base's MCP servers"

echo "PASS: deploy-profile.sh replaces stale state and layers base + profile MCP, plugins, settings, rules"
