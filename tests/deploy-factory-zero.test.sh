#!/bin/bash
set -euo pipefail

# deploy-factory-zero.sh is both the factory-zero profile and the teardown every
# other profile runs first, so it has to remove everything that steers the model
# while keeping what is not ours (user app state, hooks, engine settings), and it
# must refuse to rm -rf anything that is not a Claude home.
#
# Runs against a fixture copy whose base/settings.json carries the keys the
# teardown strips and the keys it keeps; the shipped base has only empty plugin
# maps, which would make "kept" and "stripped" indistinguishable.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"
cat > "$REPO/base/settings.json" <<'JSON'
{
  "model": "fixture-model",
  "permissions": { "deny": ["Read(./.env)"] },
  "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": "{{CLAUDE_DIR}}/hooks/stop.sh {{HOME}}" }] }] },
  "enabledPlugins": { "base-plugin@example-market": true },
  "extraKnownMarketplaces": { "example-market": { "source": { "source": "github", "repo": "your-org/your-repo" } } },
  "statusLine": { "type": "command", "command": "status" },
  "outputStyle": "concise"
}
JSON

FAKE_HOME="$TMP_DIR/home"
CD="$FAKE_HOME/.claude"
mkdir -p "$CD/rules" "$CD/skills/some-skill" "$CD/output-styles" "$CD/hooks"
printf '# user instructions\n' > "$CD/CLAUDE.md"
printf '# a rule\n' > "$CD/rules/example.md"
printf 'SKILL\n' > "$CD/skills/some-skill/SKILL.md"
printf '# style\n' > "$CD/output-styles/some-style.md"
printf '#!/bin/bash\n' > "$CD/hooks/keep-me.sh"
# The fixture registers hooks/stop.sh; a later profile deploy verifies it exists.
printf '#!/bin/bash\n' > "$CD/hooks/stop.sh"
chmod +x "$CD/hooks/stop.sh"
echo '{ "enabledPlugins": { "stale@market": true }, "outputStyle": "some-style" }' > "$CD/settings.json"
cat > "$FAKE_HOME/.claude.json" <<'JSON'
{
  "mcpServers": { "stale-server": { "command": "bash" } },
  "projects": { "/some/dir": { "mcpServers": { "local-thing": {} } } },
  "oauthAccount": { "emailAddress": "your-personal-email@example.com" }
}
JSON

HOME="$FAKE_HOME" "$REPO/scripts/deploy-factory-zero.sh" > "$TMP_DIR/out" 2>&1 \
  || { cat "$TMP_DIR/out"; fail "deploy-factory-zero.sh exited non-zero"; }

[[ ! -f "$CD/CLAUDE.md" ]] || fail "CLAUDE.md was not removed"
[[ -z "$(ls -A "$CD/rules")" ]] || fail "rules/ not empty"
[[ -z "$(ls -A "$CD/skills")" ]] || fail "skills/ not empty"
[[ -z "$(ls -A "$CD/output-styles")" ]] || fail "output-styles/ not empty"
# Hooks stay: plugins may keep hook files there, and nothing registers ours.
[[ -f "$CD/hooks/keep-me.sh" ]] || fail "hooks/ was touched"

# .claude.json: servers cleared, everything else Claude Code stores kept.
[[ "$(jq '.mcpServers | length' "$FAKE_HOME/.claude.json")" -eq 0 ]] || fail "mcpServers not cleared"
jq -e '.projects["/some/dir"].mcpServers["local-thing"]' "$FAKE_HOME/.claude.json" >/dev/null \
  || fail "project-scoped MCP config was clobbered"
jq -e '.oauthAccount.emailAddress' "$FAKE_HOME/.claude.json" >/dev/null || fail "oauthAccount was clobbered"

# settings.json is base minus the profile-layer keys, with placeholders resolved.
# Engine settings (model) and other base keys must survive, so a comparison
# against factory-zero changes only the instructions.
EXPECTED=$(jq -S --arg cd "$CD" --arg h "$FAKE_HOME" '
  del(.enabledPlugins, .extraKnownMarketplaces, .statusLine, .outputStyle)
  | .hooks.Stop[0].hooks[0].command = ($cd + "/hooks/stop.sh " + $h)' "$REPO/base/settings.json")
ACTUAL=$(jq -S . "$CD/settings.json")
[[ "$ACTUAL" == "$EXPECTED" ]] || fail "settings.json is $ACTUAL, expected $EXPECTED"

# Running it again is a no-op, not an error.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-factory-zero.sh" > /dev/null 2>&1 || fail "second teardown failed"

# deploy-profile.sh factory-zero takes the same path from a fully deployed home.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null
HOME="$FAKE_HOME" "$REPO/scripts/deploy-profile.sh" personal > /dev/null 2>&1 || fail "personal deploy failed"
[[ -f "$CD/CLAUDE.md" ]] || fail "precondition: personal deploy wrote no CLAUDE.md"
HOME="$FAKE_HOME" "$REPO/scripts/deploy-profile.sh" factory-zero > /dev/null 2>&1 || fail "factory-zero profile deploy failed"
[[ ! -f "$CD/CLAUDE.md" && -z "$(ls -A "$CD/rules")" && -z "$(ls -A "$CD/skills")" ]] \
  || fail "deploy-profile.sh factory-zero left steering files behind"
jq -e '(.enabledPlugins // {} | length) == 0 and (has("outputStyle") | not)' "$CD/settings.json" >/dev/null \
  || fail "deploy-profile.sh factory-zero left plugins or an output style enabled"

# Safety: a target that is not ~/.claude or ~/.claude-<name> is refused before
# anything is deleted.
ODD="$FAKE_HOME/not-a-claude-home"
mkdir -p "$ODD/rules"
printf 'keep\n' > "$ODD/rules/sentinel.md"
if HOME="$FAKE_HOME" CLAUDE_TARGET_DIR="$ODD" "$REPO/scripts/deploy-factory-zero.sh" >/dev/null 2>&1; then
  fail "teardown accepted a target outside ~/.claude[-<name>]"
fi
[[ -f "$ODD/rules/sentinel.md" ]] || fail "refused teardown still deleted files"
if HOME="$FAKE_HOME" CLAUDE_TARGET_DIR="$FAKE_HOME/.claude-" "$REPO/scripts/deploy-factory-zero.sh" >/dev/null 2>&1; then
  fail "teardown accepted ~/.claude- with an empty name"
fi

echo "PASS: factory-zero strips steering, keeps app state, hooks, and engine settings, and refuses odd targets"
