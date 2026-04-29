#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

FAKE_HOME="$TMP_DIR/home"
mkdir -p "$FAKE_HOME"

HOME="$FAKE_HOME" "$ROOT_DIR/scripts/deploy-codex.sh" work > "$TMP_DIR/deploy.out"

[[ -f "$FAKE_HOME/.codex/AGENTS.md" ]] \
  || fail "deploy-codex.sh did not generate AGENTS.md"

[[ -f "$FAKE_HOME/.codex/config.toml" ]] \
  || fail "deploy-codex.sh did not generate config.toml"

[[ -d "$FAKE_HOME/.codex/skills" ]] \
  || fail "deploy-codex.sh did not deploy shared skills"

[[ ! -f "$FAKE_HOME/.codex/hooks.json" ]] \
  || fail "deploy-codex.sh deployed hooks even though hooks are not enabled by default"

if grep -Eq 'context-mode|superpowers|codex_hooks' "$FAKE_HOME/.codex/config.toml"; then
  fail "default Codex config contains context-mode, Superpowers, or Codex hook settings"
fi

echo "PASS: deploy-codex.sh keeps default Codex config plugin-neutral"
