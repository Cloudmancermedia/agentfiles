#!/bin/bash
set -euo pipefail

# Output styles: deploy-output-styles.sh copies base/output-styles/*.md into a
# home, replacing each `<!-- include: path -->` line with that file, so shared
# text keeps one source. A missing include must fail rather than ship a style
# with a hole in it. A profile selects a style through "outputStyle" in its
# settings.json, and deploy-profile.sh verifies the selected file exists.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

FAKE_HOME="$TMP_DIR/home"
STYLES="$FAKE_HOME/.claude/output-styles"
mkdir -p "$FAKE_HOME/.claude"

# --- The shipped styles, against the real repo ------------------------------
HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-output-styles.sh" > /dev/null
shipped=0
for src in "$ROOT_DIR"/base/output-styles/*.md; do
  [[ -f "$src" ]] || continue
  out="$STYLES/$(basename "$src")"
  [[ -f "$out" ]] || fail "$(basename "$src") not deployed"
  grep -q '<!-- include:' "$out" && fail "$(basename "$src"): include marker left unexpanded"
  # Every included file's text must be in the output.
  while IFS= read -r inc; do
    grep -Fqx "$(head -1 "$ROOT_DIR/$inc")" "$out" || fail "$(basename "$src"): $inc was not inlined"
  done < <(sed -nE 's/^<!--[[:space:]]*include:[[:space:]]*(.+\.md)[[:space:]]*-->$/\1/p' "$src")
  shipped=$((shipped + 1))
done
[[ "$shipped" -gt 0 ]] || fail "repo ships no output styles to check"

# --- Fixtures: expansion details and the missing-include failure ------------
SRC="$TMP_DIR/styles"
mkdir -p "$SRC"
# Include paths resolve against the repo root, not the style's dir, so the
# fixture includes base/style-pointer.md, which the repo ships.
cat > "$SRC/fixture.md" <<'EOF'
---
name: fixture
---
before
<!-- include: base/style-pointer.md -->
after
  <!-- include: base/style-pointer.md --> indented markers are left as text
EOF
HOME="$FAKE_HOME" OUTPUT_STYLES_SOURCE_DIR="$SRC" "$ROOT_DIR/scripts/deploy-output-styles.sh" > /dev/null \
  || fail "fixture style deploy failed"
{
  printf -- '---\nname: fixture\n---\nbefore\n'
  cat "$ROOT_DIR/base/style-pointer.md"
  printf 'after\n  <!-- include: base/style-pointer.md --> indented markers are left as text\n'
} > "$TMP_DIR/expected.md"
cmp -s "$TMP_DIR/expected.md" "$STYLES/fixture.md" \
  || { diff "$TMP_DIR/expected.md" "$STYLES/fixture.md" >&2 || true; fail "include expansion output differs"; }

printf 'x\n<!-- include: base/no-such-file.md -->\n' > "$SRC/broken.md"
if HOME="$FAKE_HOME" OUTPUT_STYLES_SOURCE_DIR="$SRC" "$ROOT_DIR/scripts/deploy-output-styles.sh" > "$TMP_DIR/out" 2>&1; then
  fail "a style with a missing include deployed without error"
fi
grep -q 'includes missing file: base/no-such-file.md' "$TMP_DIR/out" || fail "missing include not named in the error"

# --- Selection through a profile settings overlay ---------------------------
REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
tar -cf - -C "$ROOT_DIR" --exclude='.git' --exclude='.claude' --exclude='local' . | tar -xf - -C "$REPO"
STYLE_NAME=$(basename "$(ls "$REPO"/base/output-styles/*.md | head -1)" .md)

HOME2="$TMP_DIR/home2"
mkdir -p "$HOME2/.claude/output-styles"
printf '# stale\n' > "$HOME2/.claude/output-styles/stale.md"
HOME="$HOME2" "$REPO/scripts/deploy-shared-skills.sh" > /dev/null

printf '{ "outputStyle": "%s" }\n' "$STYLE_NAME" > "$REPO/profiles/personal/settings.json"
HOME="$HOME2" "$REPO/scripts/deploy-profile.sh" personal > "$TMP_DIR/out" 2>&1 \
  || { cat "$TMP_DIR/out"; fail "deploy with outputStyle '$STYLE_NAME' selected failed"; }
[[ "$(jq -r .outputStyle "$HOME2/.claude/settings.json")" == "$STYLE_NAME" ]] \
  || fail "outputStyle selection did not reach the deployed settings"
[[ -f "$HOME2/.claude/output-styles/$STYLE_NAME.md" ]] || fail "selected style file not deployed"
[[ ! -e "$HOME2/.claude/output-styles/stale.md" ]] || fail "stale style survived the profile deploy"
grep -q "output style '$STYLE_NAME' deployed and selected" "$TMP_DIR/out" \
  || fail "verification did not confirm the selected style"

# Selecting a style that does not exist must fail verification.
printf '{ "outputStyle": "no-such-style" }\n' > "$REPO/profiles/personal/settings.json"
if HOME="$HOME2" "$REPO/scripts/deploy-profile.sh" personal > "$TMP_DIR/out" 2>&1; then
  fail "deploy passed with a selected style that has no file"
fi
grep -q "outputStyle 'no-such-style' selected" "$TMP_DIR/out" || fail "missing selected style not reported"

echo "PASS: output styles deploy with includes expanded, a missing include fails, and a profile-selected style is verified"
