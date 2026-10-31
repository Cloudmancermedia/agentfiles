#!/bin/bash
set -euo pipefail

# Score lab runs: one row per arm and prompt, averaged over reps.
#
#   scripts/lab/score.sh <arm> [<arm> ...]
#
# Columns:
#   ctx     input tokens on the first top-level request (input + cache writes +
#           cache reads), the resident context Claude starts with
#   endctx  input tokens on the last top-level request, how far context grew
#   agents  Agent tool calls by the main session
#   skills  Skill tool calls
#   checks  Bash calls running npm test or node --test, any session
#   words   words in the final reply
#   dash    em dashes per 100 words of the final reply
#   tells   hits from the writing-rules tell list in the final reply
#   fdash   em dashes per 100 words of Markdown the run wrote to files
#   ftells  tell-list hits in that Markdown
#   cost    total_cost_usd from the result event
#
# Behavior is noisy: compare arms on the same prompt across several reps, and
# treat a difference smaller than the spread between reps as no difference.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
(( $# )) || { echo "usage: scripts/lab/score.sh <arm> [<arm> ...]" >&2; exit 1; }

# "Let me" counts only as an opener; mid-sentence ("let me run it") is fine.
TELLS='successfully|comprehensive|robust|seamless|leverage|utilize|delve|pivotal|underscore|^Let me|Great question|let me know if'

score_run() {
  jq -rs --arg tells "$TELLS" '
    def top: select(.parent_tool_use_id == null);
    def tools: [.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")];
    (map(select(.type == "assistant")) | map(top) | first | .message.usage) as $u |
    (map(select(.type == "assistant")) | map(top) | last | .message.usage) as $e |
    (map(select(.type == "result")) | last) as $r |
    ($r.result // "") as $text |
    ($text | [splits("\\s+")] | map(select(length > 0)) | length) as $words |
    (tools | map(select((.name == "Write" or .name == "Edit") and ((.input.file_path // "") | endswith(".md")))
           | (.input.content // .input.new_string // "")) | join("\n")) as $prose |
    ($prose | [splits("\\s+")] | map(select(length > 0)) | length) as $pwords |
    [
      (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)),
      (($e.input_tokens // 0) + ($e.cache_creation_input_tokens // 0) + ($e.cache_read_input_tokens // 0)),
      ([.[] | select(.type == "assistant") | top | .message.content[]? | select(.type == "tool_use" and .name == "Agent")] | length),
      (tools | map(select(.name == "Skill")) | length),
      (tools | map(select(.name == "Bash" and ((.input.command // "") | test("npm test|node --test")))) | length),
      $words,
      (if $words > 0 then ([$text | scan("—")] | length) * 100 / $words else 0 end),
      ([$text | scan($tells; "i")] | length),
      (if $pwords > 0 then ([$prose | scan("—")] | length) * 100 / $pwords else 0 end),
      ([$prose | scan($tells; "i")] | length),
      ($r.total_cost_usd // 0)
    ] | @tsv
  ' "$1"
}

printf '%-14s %-12s %4s %7s %7s %6s %6s %6s %6s %5s %5s %5s %6s %6s\n' \
  arm prompt reps ctx endctx agents skills checks words dash tells fdash ftells cost
for arm in "$@"; do
  dir="$ROOT_DIR/local/lab-results/$arm"
  [[ -d "$dir" ]] || { echo "no results for $arm" >&2; continue; }
  for prompt in $(ls "$dir"/*.jsonl 2>/dev/null | xargs -n1 basename | sed -E 's/-[0-9]+\.jsonl$//' | sort -u); do
    for f in "$dir/$prompt"-*.jsonl; do score_run "$f"; done \
      | awk -v arm="$arm" -v p="$prompt" '
          { n++; for (i = 1; i <= NF; i++) s[i] += $i }
          END { printf "%-14s %-12s %4d %7d %7d %6.1f %6.1f %6.1f %6d %5.1f %5.1f %5.1f %6.1f %6.2f\n",
                arm, p, n, s[1]/n, s[2]/n, s[3]/n, s[4]/n, s[5]/n, s[6]/n, s[7]/n, s[8]/n, s[9]/n, s[10]/n, s[11]/n }'
  done
done
