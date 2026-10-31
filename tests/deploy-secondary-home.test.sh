#!/bin/bash
set -euo pipefail

# Two homes on one machine: personal into ~/.claude, work into ~/.claude-work
# (CLAUDE_TARGET_DIR). The homes must stay isolated: each links its own skills,
# registers hooks under its own dir, keeps its own .claude.json, picks up its own
# homes/<label>/settings.json, and a config re-lay never touches user state
# such as session history. bin/claude-home must launch against the right one.
#
# Runs in a fixture copy so a hook registration and per-home overlays exist; the
# shipped profiles register no hooks and both home overlays are identical.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"

# Fixture: a base hook registered through the {{CLAUDE_DIR}} placeholder, so
# each home must resolve it to its own hooks/ dir.
printf '#!/bin/bash\nexit 0\n' > "$REPO/base/hooks/fixture-hook.sh"
jq '.hooks = {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "{{CLAUDE_DIR}}/hooks/fixture-hook.sh"}]}]}' \
  "$ROOT_DIR/base/settings.json" > "$REPO/base/settings.json"
# Fixture: work gets its own MCP server and a distinct home overlay value.
echo '{ "work-srv": { "command": "work-cmd" } }' > "$REPO/profiles/work/mcp-servers.json"
echo '{ "model": "fixture-work-model" }' > "$REPO/homes/work/settings.json"
echo '{ "model": "fixture-personal-model" }' > "$REPO/homes/personal/settings.json"

FAKE_HOME="$TMP_DIR/home"
WORK_HOME="$FAKE_HOME/.claude-work"
mkdir -p "$FAKE_HOME"

HOME="$FAKE_HOME" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null

# User state a config deploy must never touch.
mkdir -p "$WORK_HOME/projects/some-session"
printf 'transcript line\n' > "$WORK_HOME/projects/some-session/chat.jsonl"

HOME="$FAKE_HOME" "$REPO/scripts/deploy-profile.sh" personal > "$TMP_DIR/out-personal" 2>&1 \
  || { cat "$TMP_DIR/out-personal"; fail "personal deploy exited non-zero"; }
PERSONAL_JSON=$(cat "$FAKE_HOME/.claude.json")

# No CLAUDE_HOME_LABEL: the label "work" must be derived from ~/.claude-work.
HOME="$FAKE_HOME" CLAUDE_TARGET_DIR="$WORK_HOME" \
  "$REPO/scripts/deploy-profile.sh" work > "$TMP_DIR/out-work" 2>&1 \
  || { cat "$TMP_DIR/out-work"; fail "work deploy into the second home exited non-zero"; }

check_skills() {
  local claude_dir="$1" profile="$2" expected=() line count skill
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && expected+=("$line")
  done < <("$REPO/scripts/profile-skills.sh" "$profile")
  count=$(find "$claude_dir/skills" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | wc -l | tr -d ' ')
  [[ "$count" -eq ${#expected[@]} ]] || fail "$profile skills/ has $count entries, expected ${#expected[@]}"
  for skill in "${expected[@]}"; do
    [[ "$(readlink "$claude_dir/skills/$skill")" == "$FAKE_HOME/.claude-shared/skills/$skill" ]] \
      || fail "$profile skill '$skill' is not a symlink into the shared store"
  done
}
check_skills "$FAKE_HOME/.claude" personal
check_skills "$WORK_HOME" work

# Each home's hook registration points into its own hooks/ and the file is there.
for dir in "$FAKE_HOME/.claude" "$WORK_HOME"; do
  cmd=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$dir/settings.json")
  [[ "$cmd" == "$dir/hooks/fixture-hook.sh" ]] || fail "hook in $dir registered as '$cmd'"
  [[ -x "$cmd" ]] || fail "hook script missing or not executable: $cmd"
done

# App state: the second home's .claude.json lives inside it, and deploying it
# leaves the default home's ~/.claude.json untouched.
[[ "$(jq -r '.mcpServers | keys | join(",")' "$WORK_HOME/.claude.json")" == "work-srv" ]] \
  || fail "second home .claude.json mcpServers is $(jq -c '.mcpServers' "$WORK_HOME/.claude.json")"
[[ "$(cat "$FAKE_HOME/.claude.json")" == "$PERSONAL_JSON" ]] \
  || fail "deploying the second home modified ~/.claude.json"

# Each home takes the overlay matching its label, not its profile.
[[ "$(jq -r .model "$FAKE_HOME/.claude/settings.json")" == "fixture-personal-model" ]] \
  || fail "default home did not get homes/personal/settings.json"
[[ "$(jq -r .model "$WORK_HOME/settings.json")" == "fixture-work-model" ]] \
  || fail "second home did not get homes/work/settings.json"

[[ "$(cat "$WORK_HOME/projects/some-session/chat.jsonl")" == "transcript line" ]] \
  || fail "session history in the second home did not survive the deploy"

for f in "$FAKE_HOME/.claude/settings.json" "$FAKE_HOME/.claude.json" \
         "$WORK_HOME/settings.json" "$WORK_HOME/.claude.json"; do
  grep -q '{{CLAUDE_DIR}}\|{{HOME}}' "$f" && fail "unresolved placeholder in $f"
done

# bin/claude-home looks the label up in local/.homes and execs claude with
# CLAUDE_CONFIG_DIR set to that home. A fake binary records what it received.
mkdir -p "$REPO/local"
printf 'personal\tpersonal\t~/.claude\nwork\twork\t~/.claude-work\n' > "$REPO/local/.homes"
FAKE_BIN="$TMP_DIR/fake-claude"
printf '#!/bin/bash\necho "$CLAUDE_CONFIG_DIR|$*"\n' > "$FAKE_BIN"
chmod +x "$FAKE_BIN"
got=$(HOME="$FAKE_HOME" CLAUDE_REAL_BIN="$FAKE_BIN" "$REPO/bin/claude-home" work --print hi)
[[ "$got" == "$WORK_HOME|--print hi" ]] || fail "claude-home work launched with '$got'"
got=$(HOME="$FAKE_HOME" CLAUDE_REAL_BIN="$FAKE_BIN" "$REPO/bin/claude-home" personal)
[[ "$got" == "$FAKE_HOME/.claude|" ]] || fail "claude-home personal launched with '$got'"
if HOME="$FAKE_HOME" CLAUDE_REAL_BIN="$FAKE_BIN" "$REPO/bin/claude-home" no-such-home >/dev/null 2>&1; then
  fail "claude-home accepted an unknown label"
fi

echo "PASS: two homes stay isolated (skills, hooks, app state, home overlay) and claude-home targets each"
