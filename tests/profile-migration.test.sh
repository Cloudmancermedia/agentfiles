#!/bin/bash
set -euo pipefail

# local/ is per-machine and gitignored, so a change to its format cannot ship in
# a commit: resolve-homes.sh has to migrate it at runtime. A machine that only
# has the single-home local/.current-profile must get an equivalent one-row
# local/.homes, or sync fails on its first run after upgrading.
#
# Also covers the table itself (any profile binds to any home, bad rows fail
# loudly) and switch-profile.sh rebinding one row without disturbing the rest.
#
# Works in a throwaway copy of the repo so the real local/ is never touched.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="$TMP_DIR/repo"
FAKE_HOME="$TMP_DIR/home"
LOCAL="$REPO/local"
mkdir -p "$REPO" "$FAKE_HOME"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"

resolve() { HOME="$FAKE_HOME" "$REPO/scripts/resolve-homes.sh" "$@"; }

# --- Nothing to migrate from: fail with a pointer, not an empty table --------
if resolve >/dev/null 2>&1; then
  fail "resolve-homes.sh succeeded with neither .homes nor .current-profile"
fi

# --- Legacy single-home state migrates to a one-row table --------------------
mkdir -p "$LOCAL"
printf 'work\n' > "$LOCAL/.current-profile"
ROWS=$(resolve 2>"$TMP_DIR/migrate-err")
[[ "$ROWS" == $'personal\twork\t'"$FAKE_HOME/.claude" ]] \
  || fail "migrated table is '$ROWS', expected the default home bound to work"
[[ -f "$LOCAL/.homes" ]] || fail ".homes was not written"
grep -q 'migrated' "$TMP_DIR/migrate-err" || fail "migration was not reported"
[[ -f "$LOCAL/.current-profile" ]] || fail "migration deleted the legacy file"

# Once .homes exists the legacy file is no longer read, and nothing re-migrates.
printf 'personal\n' > "$LOCAL/.current-profile"
ROWS2=$(resolve 2>"$TMP_DIR/rerun-err")
[[ "$ROWS2" == "$ROWS" ]] || fail "second run changed the table (legacy file was re-read)"
grep -q 'migrated' "$TMP_DIR/rerun-err" && fail "second run migrated again"

# --- The table: any profile to any home, comments and blanks ignored ---------
cat > "$LOCAL/.homes" <<'EOF'
# <label>  <profile>  <dir>

personal    factory-zero   ~/.claude
work        personal       ~/.claude-work   # trailing comment
EOF
REBOUND=$(resolve)
[[ "$REBOUND" == $'personal\tfactory-zero\t'"$FAKE_HOME/.claude"$'\nwork\tpersonal\t'"$FAKE_HOME/.claude-work" ]] \
  || fail "rebound table resolved to: $REBOUND"

printf 'work  no-such-profile  ~/.claude-work\n' > "$LOCAL/.homes"
resolve >/dev/null 2>&1 && fail "a row naming an unknown profile was accepted"
printf 'work  personal\n' > "$LOCAL/.homes"
resolve >/dev/null 2>&1 && fail "a row with a missing column was accepted"
printf '# only comments\n\n' > "$LOCAL/.homes"
resolve >/dev/null 2>&1 && fail "a table with no rows was accepted"

# --- switch-profile.sh rebinds one row and leaves the others alone ----------
# .enabled-tools without "claude" or "codex" makes it rebind without deploying.
printf 'none\n' > "$LOCAL/.enabled-tools"
switch() { HOME="$FAKE_HOME" "$REPO/switch-profile.sh" "$@" >/dev/null 2>&1; }

# Both separators: migrate() writes tabs, but the documented hand-written
# format (and resolve-homes.sh) accepts any whitespace.
for sep in tab space; do
  if [[ "$sep" == tab ]]; then
    printf '# header\npersonal\tpersonal\t~/.claude\nwork\twork\t~/.claude-work\n' > "$LOCAL/.homes"
  else
    printf '# header\npersonal    personal   ~/.claude\nwork        work       ~/.claude-work\n' > "$LOCAL/.homes"
  fi

  switch work factory-zero || fail "[$sep] switch-profile.sh work factory-zero exited non-zero"
  got=$(resolve)
  [[ "$got" == $'personal\tpersonal\t'"$FAKE_HOME/.claude"$'\nwork\tfactory-zero\t'"$FAKE_HOME/.claude-work" ]] \
    || fail "[$sep] after switching the work home, the table is: $got"
  grep -q '^# header' "$LOCAL/.homes" || fail "[$sep] switch-profile.sh dropped the comment line"

  # One argument targets the default home (~/.claude), whatever its label.
  switch work || fail "[$sep] switch-profile.sh work exited non-zero"
  got=$(resolve)
  [[ "$got" == $'personal\twork\t'"$FAKE_HOME/.claude"$'\nwork\tfactory-zero\t'"$FAKE_HOME/.claude-work" ]] \
    || fail "[$sep] after switching the default home, the table is: $got"

  switch no-such-home personal && fail "[$sep] switch-profile.sh accepted an unknown home"
done

echo "PASS: .current-profile migrates to .homes once; the table binds any profile to any home; switch-profile rebinds one row"
