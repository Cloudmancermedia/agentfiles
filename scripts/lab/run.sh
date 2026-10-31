#!/bin/bash
set -euo pipefail

# Run the lab prompt set against whatever is deployed in the lab home.
#
#   scripts/lab/run.sh <arm> [reps] [prompt-glob[,prompt-glob...]]
#
# <arm> names the result folder (e.g. main, no-dispatcher). Each run gets a fresh
# copy of scripts/lab/fixture as a new git repo, so runs never see each other.
# Results go to local/lab-results/<arm>/<prompt>-<n>.jsonl (gitignored), with the
# deployed commit recorded in local/lab-results/<arm>/deployed.
#
# Safety: --permission-mode dontAsk denies every tool call not on the allowlist
# below, so claude.ai connector writes, cloud CLIs, and pushes can't run. Each run
# is capped at --max-budget-usd. Every run spends real tokens on the lab login.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB_DIR="$ROOT_DIR/scripts/lab"
LAB_CONFIG="$HOME/.claude-lab/home/.claude-lab"
ARM="${1:?usage: scripts/lab/run.sh <arm> [reps] [prompt-glob]}"
REPS="${2:-3}"
GLOB="${3:-*}"
MODEL="${LAB_MODEL:-claude-opus-5-5}"
EFFORT="${LAB_EFFORT:-medium}"
BUDGET="${LAB_BUDGET_USD:-1}"

[[ -f "$HOME/.claude-lab/deployed" ]] || { echo "ERROR: nothing deployed; run scripts/lab/deploy.sh first" >&2; exit 1; }
OUT_DIR="$ROOT_DIR/local/lab-results/$ARM"
mkdir -p "$OUT_DIR"
cp "$HOME/.claude-lab/deployed" "$OUT_DIR/deployed"

ALLOWED=(Read Glob Grep Edit Write Agent Skill TodoWrite
  "Bash(npm test:*)" "Bash(node:*)" "Bash(ls:*)" "Bash(cat:*)"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)"
  "Bash(grep:*)" "Bash(wc:*)" "Bash(sort:*)" "Bash(uniq:*)" "Bash(head:*)" "Bash(tail:*)")

PROMPTS=()
IFS=, read -ra GLOBS <<< "$GLOB"
for g in "${GLOBS[@]}"; do
  matched=0
  for f in "$LAB_DIR"/prompts/$g.txt; do
    [[ -f "$f" ]] && { PROMPTS+=("$f"); matched=1; }
  done
  (( matched )) || { echo "ERROR: no prompt matches '$g'" >&2; exit 1; }
done

for prompt_file in "${PROMPTS[@]}"; do
  name=$(basename "$prompt_file" .txt)
  for n in $(seq 1 "$REPS"); do
    out="$OUT_DIR/$name-$n.jsonl"
    [[ -s "$out" ]] && { echo "skip $name-$n (exists)"; continue; }
    work=$(mktemp -d)
    cp -R "$LAB_DIR/fixture/." "$work/"
    (cd "$work" && git init -q && git add -A && git -c user.name=lab -c user.email=lab@localhost commit -qm fixture)
    setup="$LAB_DIR/prompts/$name.setup.sh"
    [[ -f "$setup" ]] && (cd "$work" && bash "$setup")
    echo "run $ARM/$name-$n"
    # claude.ai connectors finish loading before the first request in some runs
    # and not others, which swings the starting context by ~7.7K tokens. Keep
    # them off so arms differ only by deployed config.
    (cd "$work" && env -u CLAUDE_CODE_EFFORT_LEVEL CLAUDE_CONFIG_DIR="$LAB_CONFIG" \
      ENABLE_CLAUDEAI_MCP_SERVERS=false \
      claude -p "$(cat "$prompt_file")" \
        --output-format stream-json --verbose \
        --model "$MODEL" --effort "$EFFORT" --max-budget-usd "$BUDGET" \
        --no-session-persistence --permission-mode dontAsk \
        --allowedTools "${ALLOWED[@]}" \
      > "$out.tmp" 2> "$out.err") || echo "  exited non-zero, see $out.err"
    mv "$out.tmp" "$out"
    rm -rf "$work"
  done
done
