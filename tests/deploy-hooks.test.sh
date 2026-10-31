#!/bin/bash
set -euo pipefail

# Hook scripts deploy in two layers (base/hooks, then profiles/<p>/hooks, a
# later file of the same name winning), top-level files only so
# base/hooks/examples/ stays undeployed, and without pruning, because plugins can
# keep their own files in hooks/. deploy-profile.sh then checks that every
# script the settings register exists and, for .sh, is executable, so a
# registration pointing at nothing fails the deploy instead of failing silently
# at runtime.
#
# The shipped profiles carry no hooks, so this runs on a fixture copy.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"

[[ -d "$REPO/base/hooks/examples" ]] && [[ -n "$(ls -A "$REPO/base/hooks/examples")" ]] \
  || fail "fixture setup: base/hooks/examples/ is empty, so the skip check would prove nothing"

mkdir -p "$REPO/profiles/work/hooks"
printf '#!/bin/bash\necho base\n' > "$REPO/base/hooks/base-hook.sh"
printf '#!/bin/bash\necho base-version\n' > "$REPO/base/hooks/shared.sh"
printf 'not a script\n' > "$REPO/base/hooks/notes.txt"
printf '#!/bin/bash\necho work\n' > "$REPO/profiles/work/hooks/work-hook.sh"
printf '#!/bin/bash\necho work-version\n' > "$REPO/profiles/work/hooks/shared.sh"
chmod -x "$REPO"/base/hooks/*.sh "$REPO"/profiles/work/hooks/*.sh

FAKE_HOME="$TMP_DIR/home"
HOOKS="$FAKE_HOME/.claude/hooks"
mkdir -p "$HOOKS"
# A file some other tool put there; a deploy must leave it alone.
printf 'foreign\n' > "$HOOKS/foreign-hook.sh"

# --- deploy-hooks.sh on its own ---------------------------------------------
HOME="$FAKE_HOME" "$REPO/scripts/deploy-hooks.sh" work > /dev/null

for f in base-hook.sh work-hook.sh shared.sh; do
  [[ -x "$HOOKS/$f" ]] || fail "$f not deployed or not executable"
done
[[ -f "$HOOKS/notes.txt" ]] || fail "a non-.sh top-level file was not deployed"
[[ "$(tail -1 "$HOOKS/shared.sh")" == "echo work-version" ]] \
  || fail "profile hook did not override the base hook of the same name"
[[ ! -e "$HOOKS/examples" ]] || fail "base/hooks/examples/ was deployed as a directory"
for ex in "$REPO"/base/hooks/examples/*; do
  [[ ! -e "$HOOKS/$(basename "$ex")" ]] || fail "example hook $(basename "$ex") was deployed"
done
[[ "$(cat "$HOOKS/foreign-hook.sh")" == "foreign" ]] || fail "deploy touched a hook it does not own"

# Another profile gets base's hooks only; no pruning means the work hook from
# the earlier run stays, but the shared file reverts to base's version.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-hooks.sh" personal > /dev/null
[[ "$(tail -1 "$HOOKS/shared.sh")" == "echo base-version" ]] \
  || fail "personal deploy did not lay base's shared.sh"
[[ -f "$HOOKS/work-hook.sh" ]] || fail "deploy pruned a hook (documented as no pruning)"
HOME="$FAKE_HOME" CLAUDE_TARGET_DIR="$FAKE_HOME/.claude-other" "$REPO/scripts/deploy-hooks.sh" personal > /dev/null
[[ -f "$FAKE_HOME/.claude-other/hooks/base-hook.sh" ]] || fail "CLAUDE_TARGET_DIR was not honored"
[[ ! -f "$FAKE_HOME/.claude-other/hooks/work-hook.sh" ]] || fail "personal received the work-only hook"

# --- Registration verification in deploy-profile.sh -------------------------
register() {
  # $1: JSON array of hook command strings, registered under PreToolUse.
  jq --argjson cmds "$1" '.hooks = {"PreToolUse": [{"matcher": "Bash",
      "hooks": [$cmds[] | {"type": "command", "command": .}]}]}' \
    "$ROOT_DIR/base/settings.json" > "$REPO/base/settings.json"
}
deploy() { HOME="$FAKE_HOME" "$REPO/scripts/deploy-profile.sh" work > "$TMP_DIR/out" 2>&1; }
HOME="$FAKE_HOME" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null

# Registered scripts that the deploy lays down, plus a PATH command (no "/"),
# which is not ours to verify.
register '["{{CLAUDE_DIR}}/hooks/base-hook.sh", "{{CLAUDE_DIR}}/hooks/work-hook.sh --flag", "some-cli check"]'
deploy || { cat "$TMP_DIR/out"; fail "deploy failed with every registered hook present"; }
[[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$FAKE_HOME/.claude/settings.json")" == "$HOOKS/base-hook.sh" ]] \
  || fail "{{CLAUDE_DIR}} not resolved in a hook registration"

# A registered script that does not exist must fail the deploy.
register '["{{CLAUDE_DIR}}/hooks/missing-hook.sh"]'
if deploy; then fail "deploy passed with a registered hook script missing"; fi
grep -q 'registered hook script missing' "$TMP_DIR/out" || fail "missing-hook failure not reported"

# A registered .sh that exists but is not executable must fail too.
printf '#!/bin/bash\n' > "$HOOKS/not-exec.sh"
chmod -x "$HOOKS/not-exec.sh"
register '["{{CLAUDE_DIR}}/hooks/not-exec.sh"]'
if deploy; then fail "deploy passed with a non-executable registered hook"; fi
grep -q 'registered hook not executable' "$TMP_DIR/out" || fail "non-executable hook failure not reported"

# A statusLine command is not a hook and must not be checked as one.
jq '.statusLine = {"type": "command", "command": "/nonexistent/statusline.sh"}' "$ROOT_DIR/base/settings.json" \
  > "$REPO/base/settings.json"
printf '{ "statusLine": { "type": "command", "command": "/nonexistent/statusline.sh" } }\n' \
  > "$REPO/profiles/work/settings.json"
deploy || { cat "$TMP_DIR/out"; fail "a statusLine command was verified as a hook"; }

echo "PASS: hooks deploy base then profile, skip examples/, never prune; missing or non-executable registered hooks fail the deploy"
