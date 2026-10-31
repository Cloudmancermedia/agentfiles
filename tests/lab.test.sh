#!/bin/bash
set -euo pipefail

# The lab (scripts/lab/, docs/lab.md) is how config changes get A/B tested. This
# guards the parts that break silently: a script that no longer parses, an empty
# prompt (a run then sends nothing and still scores), and the run safety flags.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB="$ROOT_DIR/scripts/lab"
fail() { echo "FAIL: $1" >&2; exit 1; }

for s in deploy run score; do
  bash -n "$LAB/$s.sh" || fail "scripts/lab/$s.sh does not parse"
done
for p in "$LAB"/prompts/*.txt; do
  [[ -s "$p" ]] || fail "$(basename "$p") is empty"
done
for s in "$LAB"/prompts/*.setup.sh; do
  bash -n "$s" || fail "$(basename "$s") does not parse"
done

grep -q -- '--permission-mode dontAsk' "$LAB/run.sh" || fail "run.sh lost dontAsk, so unlisted tools could run"
grep -q 'ENABLE_CLAUDEAI_MCP_SERVERS=false' "$LAB/run.sh" || fail "run.sh lets claude.ai connectors load"
grep -q -- '--max-budget-usd' "$LAB/run.sh" || fail "run.sh has no per-run budget cap"
grep -q 'LAB_CONFIG="\$FAKE_HOME/.claude-lab"' "$LAB/deploy.sh" || fail "deploy.sh target is no longer the fixed lab path"

"$LAB/deploy.sh" no-such-ref-xyz >/dev/null 2>&1 && fail "deploy.sh accepted a ref that does not exist"
[[ -f "$ROOT_DIR/docs/lab.md" ]] || fail "docs/lab.md missing"

echo "PASS: lab scripts parse, prompts are non-empty, runs stay sandboxed"
