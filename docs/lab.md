# Lab: A/B testing config changes

The lab deploys any git ref of this repo into a separate Claude home, runs a fixed
set of prompts against it with `claude -p`, and scores the transcripts. Use it before
merging anything Claude loads up front (`base/CLAUDE.md`, a rule, an output style, a
hook, a skill description), so a trim or rewrite ships with evidence that behavior
held. Your real homes and Codex are never touched.

`tests/resident-budget.test.sh` proves a change made the always-loaded text smaller.
The lab is the other half: it shows whether Claude still behaves the same.

## One-time setup

The lab home needs its own login, because Claude Code keys the Keychain entry by
the config directory:

    CLAUDE_CONFIG_DIR=$HOME/.claude-lab/home/.claude-lab claude auth login

The scripts need `claude`, `jq`, `git` and `node` on your PATH.

## Running an A/B

Deploy one ref, run the prompts, then deploy the other ref and run them again
under a different arm name. Compare arms on the same profile.

    scripts/lab/deploy.sh origin/main personal
    scripts/lab/run.sh main 4 "05-fix-test*,13-feature*"
    scripts/lab/deploy.sh my-branch personal
    scripts/lab/run.sh candidate 4 "05-fix-test*,13-feature*"
    scripts/lab/score.sh main candidate

- `deploy.sh <ref> [profile]` checks the ref out into a `lab-<sha>` worktree, runs
  that ref's own deploy scripts with `HOME` pointed at `~/.claude-lab/home`, and
  makes one cheap warm-up launch, because with plugins enabled the first launch
  after a deploy can start with some plugin skills missing.
- `run.sh <arm> [reps] [globs]` gives every run a fresh copy of
  `scripts/lab/fixture` as its own git repo, and stores the stream-json transcript in
  `local/lab-results/<arm>/`, which `local/` keeps out of git. The globs are a comma
  list matched against `scripts/lab/prompts/`. Model, effort and budget come from
  `LAB_MODEL`, `LAB_EFFORT` and `LAB_BUDGET_USD` (defaults: Opus 5.5, medium, $1 per
  run).
- `score.sh <arm>...` prints one row per arm and prompt, averaged over reps. The
  script's header defines each column.

`deploy.sh origin/main factory-zero` gives the bare Claude Code floor: no
`CLAUDE.md`, rules, custom skills, MCP servers or plugins. Measure it once with
`run.sh floor 2 "00-context*"`, so you know how much of your starting context is
your own config and how much is Claude Code itself.

## Safety

`run.sh` uses `--permission-mode dontAsk` with a read-mostly allowlist, so connector
writes, cloud CLIs and pushes are denied. It also sets
`ENABLE_CLAUDEAI_MCP_SERVERS=false`, because claude.ai connectors otherwise finish
loading in some runs and not others, which swings the starting context by thousands
of tokens. A prompt that tests how Claude would use a connector should ask for a
draft, never a write. Every run spends real tokens on the lab login: a one-word
reply costs cents, and a small feature with tests costs tens of cents.

## Reading results

Behavior is noisy. Use at least 4 reps, and treat a gap smaller than the spread
between reps as no difference.

- **Context and cost** (`ctx`, `cost`) are stable to within about 100 tokens, so 2
  reps of `00-context` are enough.
- **Behavior** (skill calls, test runs, which tool the model picked) needs the
  transcripts. Check them with `jq` on the tool_use events, as `score.sh` does.
- **Voice** cannot be scored by grep. Hand anonymized pairs of final replies to a
  blind judge agent with your style rules (`claude/rules/conversation-style.md`) as
  the rubric, and keep the key that maps each pair to an arm out of the judge's
  prompt. Include some main-vs-main pairs, so you can see the judge's own noise.

## Prompts

Each `scripts/lab/prompts/NN-name.txt` is one prompt. An optional `NN-name.setup.sh`
runs inside the fresh fixture first (`09-log` writes a 428KB log there). Add a
prompt when a change targets behavior the set does not exercise yet: a rule about
a tool you use gets a prompt that would make Claude reach for that tool.

## Teardown

    rm -rf ~/.claude-lab local/lab-results
    git worktree list | awk '/lab-/{print $1}' | xargs -n1 git worktree remove --force

Removing `~/.claude-lab` also drops the lab login, so the next use repeats setup.
