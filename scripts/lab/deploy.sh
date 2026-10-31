#!/bin/bash
set -euo pipefail

# Deploy one git ref of this repo into the lab Claude home, and nothing else.
#
#   scripts/lab/deploy.sh <git-ref> [profile]     profile defaults to personal
#
# The lab exists to A/B instruction changes without touching the real homes or
# Codex. It runs the ref's own deploy scripts with HOME pointed at a fake root
# under ~/.claude-lab, so the shared skill store and every other $HOME-relative
# write land inside the lab. That works for any ref that has
# scripts/deploy-profile.sh, including ones older than this script.
#
# Launch the lab home with:
#   CLAUDE_CONFIG_DIR="$HOME/.claude-lab/home/.claude-lab" claude
# It needs its own login once (claude auth login under that CLAUDE_CONFIG_DIR);
# the Keychain entry is keyed by the config dir path, which never changes.
#
# Teardown: rm -rf ~/.claude-lab, then git worktree remove the lab-* worktrees.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REF="${1:?usage: scripts/lab/deploy.sh <git-ref> [profile]}"
PROFILE="${2:-personal}"

# Fixed paths, never arguments: deploy-factory-zero.sh wipes its target, and its
# guard accepts any ~/.claude-<name>, so a typo must not be able to aim it at a
# real home.
LAB_ROOT="$HOME/.claude-lab"
FAKE_HOME="$LAB_ROOT/home"
LAB_CONFIG="$FAKE_HOME/.claude-lab"

git -C "$ROOT_DIR" rev-parse --verify --quiet "$REF^{commit}" >/dev/null \
  || { echo "ERROR: '$REF' is not a commit in $ROOT_DIR" >&2; exit 1; }
SHA=$(git -C "$ROOT_DIR" rev-parse --short "$REF^{commit}")

# One detached worktree per deployed commit, in the repo's canonical location.
WORKTREE="$ROOT_DIR/.claude/worktrees/lab-$SHA"
[[ -d "$WORKTREE" ]] || git -C "$ROOT_DIR" worktree add -q --detach "$WORKTREE" "$SHA"

mkdir -p "$LAB_CONFIG"
[[ -f "$LAB_CONFIG/.claude.json" ]] || echo '{}' > "$LAB_CONFIG/.claude.json"

lab_env=(env -u XDG_CONFIG_HOME -u CLAUDE_CONFIG_DIR HOME="$FAKE_HOME"
  CLAUDE_TARGET_DIR="$LAB_CONFIG" CLAUDE_HOME_LABEL="$PROFILE")

"${lab_env[@]}" "$WORKTREE/scripts/deploy-shared-skills.sh" > /dev/null
"${lab_env[@]}" "$WORKTREE/scripts/deploy-profile.sh" "$PROFILE"

# Plugins install through the claude CLI, which needs the real HOME (Keychain)
# and finds the lab home through CLAUDE_CONFIG_DIR.
if [[ -x "$WORKTREE/scripts/deploy-claude-plugins.sh" ]]; then
  CLAUDE_CONFIG_DIR="$LAB_CONFIG" "$WORKTREE/scripts/deploy-claude-plugins.sh" "$LAB_CONFIG/settings.json"
fi

# With plugins enabled, the first launch after a deploy can start with some plugin
# skills missing, which skews rep 1 of whatever runs next. One cheap launch warms
# that up.
warm=$(mktemp -d)
skills=$(cd "$warm" && ENABLE_CLAUDEAI_MCP_SERVERS=false CLAUDE_CONFIG_DIR="$LAB_CONFIG" \
  claude -p "Reply with OK." --output-format stream-json --verbose \
    --model claude-haiku-5-5 --effort low --max-budget-usd 0.2 \
    --no-session-persistence --permission-mode dontAsk 2>/dev/null \
  | jq -r 'select(.type == "system" and .subtype == "init") | .skills | length')
rm -rf "$warm"
echo "lab: warm-up launch saw ${skills:-?} skills"

echo "$SHA $PROFILE" > "$LAB_ROOT/deployed"
echo "lab: deployed $REF ($SHA) as $PROFILE into $LAB_CONFIG"
