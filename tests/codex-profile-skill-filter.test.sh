#!/bin/bash
set -euo pipefail

# Codex must receive only the skills in the profile's allowlist
# (profile-skills.sh), exactly like Claude homes do. Regression guard for the bug
# where deploy-skills.sh copied every claude/skills/* dir into ~/.codex and
# compile-agents-md.sh indexed them all, so a profile-specific skill reached
# every profile — Codex would advertise and run a workflow scoped to another
# context.
#
# The profiles this repo ships have identical allowlists, so the bug is not
# observable against them. The test builds its own fixture in a throwaway copy of
# the repo: one extra skill, allowlisted to `work` only.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="$TMP_DIR/repo"
FAKE_HOME="$TMP_DIR/home"
mkdir -p "$REPO" "$FAKE_HOME"

# Copy the repo without .git or worktrees — the scripts resolve their paths from
# their own location, so a plain copy behaves like the real thing.
tar -cf - -C "$ROOT_DIR" \
    --exclude='.git' --exclude='.claude' --exclude='local' \
    . | tar -xf - -C "$REPO"

# Fixture: a skill allowlisted to `work` and never to `personal`.
mkdir -p "$REPO/claude/skills/work-only-fixture"
cat > "$REPO/claude/skills/work-only-fixture/SKILL.md" <<'SKILL'
---
name: work-only-fixture
description: Fixture skill allowlisted to the work profile only.
---

# Work Only Fixture

Exists so the test can prove profile filtering.
SKILL

printf 'work-only-fixture\n' >> "$REPO/profiles/work/skills.txt"

# Sanity-check the fixture itself, so a later assertion failure means the deploy
# is wrong rather than the allowlist being miswired.
"$REPO/scripts/profile-skills.sh" work | grep -qx 'work-only-fixture' \
    || fail "fixture setup: work allowlist does not include work-only-fixture"
"$REPO/scripts/profile-skills.sh" personal | grep -qx 'work-only-fixture' \
    && fail "fixture setup: personal allowlist unexpectedly includes work-only-fixture"
"$REPO/scripts/profile-skills.sh" personal | grep -qx 'swarm-review' \
    || fail "fixture setup: personal allowlist lost swarm-review"

# 1. deploy-skills.sh with a profile copies only that profile's allowlist.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-skills.sh" codex personal >/dev/null
[[ -d "$FAKE_HOME/.codex/skills/swarm-review" ]] \
    || fail "allowlisted skill swarm-review missing from personal codex deploy"
[[ ! -d "$FAKE_HOME/.codex/skills/work-only-fixture" ]] \
    || fail "work-only skill leaked into the personal codex deploy"

# 2. The work profile (@include personal + its own additions) gets both sets.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-skills.sh" codex work >/dev/null
[[ -d "$FAKE_HOME/.codex/skills/work-only-fixture" ]] \
    || fail "work profile lost its own skill work-only-fixture"
[[ -d "$FAKE_HOME/.codex/skills/swarm-review" ]] \
    || fail "work profile lost the inherited personal skill swarm-review (@include broken)"

# 3. Omitting the profile keeps the legacy full deploy.
HOME="$FAKE_HOME" "$REPO/scripts/deploy-skills.sh" codex >/dev/null
[[ -d "$FAKE_HOME/.codex/skills/work-only-fixture" && -d "$FAKE_HOME/.codex/skills/swarm-review" ]] \
    || fail "no-profile deploy should copy every skill"

# 4. The AGENTS.md skill index is filtered by the same allowlist — a skill
#    outside the profile must be neither installed nor advertised.
AGENTS_OUT="$TMP_DIR/AGENTS.md"
HOME="$FAKE_HOME" "$REPO/scripts/compile-agents-md.sh" personal "$AGENTS_OUT" >/dev/null
grep -q '`swarm-review`' "$AGENTS_OUT" \
    || fail "AGENTS.md (personal) missing allowlisted skill index entry"
grep -q 'work-only-fixture' "$AGENTS_OUT" \
    && fail "AGENTS.md (personal) advertises a skill outside the profile"

HOME="$FAKE_HOME" "$REPO/scripts/compile-agents-md.sh" work "$AGENTS_OUT" >/dev/null
grep -q '`work-only-fixture`' "$AGENTS_OUT" \
    || fail "AGENTS.md (work) lost its own skill index entry"
grep -q '`swarm-review`' "$AGENTS_OUT" \
    || fail "AGENTS.md (work) lost the inherited personal skill index entry"

echo "PASS: Codex receives only the profile's allowlisted skills, and AGENTS.md indexes the same set"
