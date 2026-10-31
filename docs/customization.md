# Customization Guide

This document covers how to make agentfiles your own once you have your own copy of it. If you haven't set that up yet, start with the setup paths in the [README](../README.md#before-you-clone-public-fork-or-private-copy) — the choice between a public fork and a private copy matters if any of your configuration is work-related.

## The Core Pattern

Everything in this repo follows one rule: **base configuration is shared across all profiles, profile-specific configuration extends it.**

### Claude Code
```
base/CLAUDE.md + profiles/<profile>/CLAUDE.md.append           → ~/.claude/CLAUDE.md
base/writing-rules.md + base/rules/*.md + claude/rules/*.md + profiles/<profile>/rules/*.md → ~/.claude/rules/
base/mcp-servers-base.json + profiles/<profile>/mcp-servers.json    → ~/.claude.json
base/settings.json + profiles/<profile>/settings.json + homes/<label>/settings.json → ~/.claude/settings.json
claude/skills/*/                                                    → ~/.claude/skills/
base/hooks/* + profiles/<profile>/hooks/*                           → ~/.claude/hooks/
base/output-styles/*.md                                             → ~/.claude/output-styles/
```

### Codex CLI
```
codex/instructions.md + CLAUDE.md + writing rules + rules + skill metadata → ~/.codex/AGENTS.md
codex/config-base.toml + MCP servers (JSON→TOML)           → ~/.codex/config.toml
codex/agents/*.toml                                         → ~/.codex/agents/
claude/skills/*/                                            → ~/.codex/skills/
```

When you run `./sync.sh`, the scripts merge these layers and deploy the result to all enabled tools. There is no backup step: a deploy is a deterministic re-run from this repo, so recovering an earlier state means checking out the config you want in Git and syncing again.

## Where to Put Things

Ask yourself: **"Does this apply to all my profiles, or just one?"**

| It applies to... | Put it in... |
|---|---|
| All profiles | `base/CLAUDE.md` or `base/rules/<topic>.md` |
| Claude Code specifically | `claude/rules/<topic>.md` |
| Only work | `profiles/work/CLAUDE.md.append` or `profiles/work/rules/<topic>.md` |
| Only personal | `profiles/personal/CLAUDE.md.append` or `profiles/personal/rules/<topic>.md` |
| Both tools equally | `claude/skills/<name>/SKILL.md` (synced to both) |
| One Claude account, regardless of profile | `homes/<label>/settings.json` |

### Settings Layers: Profile vs Account

Settings have one more layer than rules do, because two different things are being described.

A **profile** is behavior — rules, skills, MCP servers, output style. An **account** (a Claude home) carries engine settings that belong to the seat itself: which `model` it runs and at what effort (`modelSettings`). Those follow the account's plan, not the rules you happen to have mounted.

```
base/settings.json                  shared defaults
  -> profiles/<name>/settings.json  behavior for this profile
    -> homes/<label>/settings.json  engine settings for this account   (wins)
```

The home layer merges last, keyed by home label rather than profile name, so switching a profile never changes that account's model. Keep these files to a couple of keys — if a setting should change when you switch profiles, it belongs in the profile instead.

On a single-home machine you can ignore this layer; the files are optional and an absent one is a no-op. Full detail in the [multi-account guide](multi-account.md#profiles-are-behavior-accounts-are-engine-settings).

### CLAUDE.md vs Rules Files

- **CLAUDE.md** — Core behavioral instructions. Things like "be concise", "always verify before claiming done", "prefer boring solutions." These are high-level principles that apply broadly.
- **Rules files** — Domain-specific standards. Things like "use 2-space indentation in TypeScript", "follow REST conventions for APIs", "test with Vitest." These are focused on a specific topic.

There's no strict boundary — use whatever organization makes sense to you. The only structural difference is that CLAUDE.md content gets concatenated (base + profile append), while rules files are individual files that get copied into `~/.claude/rules/` (or compiled into AGENTS.md sections for Codex).

### Rules Layers

Rules are deployed in three layers. Later layers override earlier ones by filename:

1. **Base rules** (`base/rules/`) — Tool-agnostic, shared across all profiles
2. **Claude-authored rules** (`claude/rules/`) — Also compiled into Codex AGENTS.md for parity
3. **Profile rules** (`profiles/<name>/rules/`) — Override base or claude rules with the same filename

### MCP Servers

MCP server configuration follows the same base + profile merge pattern:
- `base/mcp-servers-base.json` — Servers you want available in all profiles
- `profiles/<profile>/mcp-servers.json` — Servers only needed for a specific profile

Use `{{HOME}}` as a placeholder for your home directory — the sync script resolves it at deploy time so the same config works on different machines.

For Codex, the merged JSON is automatically converted to TOML `[mcp_servers.*]` sections in `config.toml`.

### Skills

Skills live in `claude/skills/<name>/SKILL.md`. See `claude/skills/SKILL-TEMPLATE.md` for the format.

Writing the file does not deploy it. A skill reaches a profile only when that profile's `skills.txt` names it:

```
# profiles/personal/skills.txt — one skill per line, comments and blanks ignored
swarm-review
```

```
# profiles/work/skills.txt — inherit another profile's list, then add to it
@include personal
some-work-only-skill
```

`@include <profile>` pulls in that profile's resolved list, so a skill added to `personal` flows into `work` automatically. `scripts/profile-skills.sh <profile>` prints the resolved list, which is the quickest way to check what a profile will actually receive.

**The allowlist governs both tools.** Claude homes get per-skill symlinks into the shared store, and Codex gets copies in `~/.codex/skills/` — both from the same resolved list. A skill outside the profile is neither installed nor advertised in the Codex `AGENTS.md` index.

### Scoping Anything to One Profile

The general rule: if something should apply in one context and not another, it belongs under `profiles/<name>/` rather than in `base/`.

| Concern | Shared | Profile-scoped |
|---|---|---|
| Instructions | `base/CLAUDE.md` | `profiles/<name>/CLAUDE.md.append` |
| Rules | `base/rules/`, `claude/rules/` | `profiles/<name>/rules/` |
| Skills | — | `profiles/<name>/skills.txt` (the allowlist) |
| MCP servers | `base/mcp-servers-base.json` | `profiles/<name>/mcp-servers.json` |
| Engine settings | `base/settings.json` | `homes/<label>/settings.json` (per account, not per profile) |
| Hooks | `base/hooks/` + registration in `base/settings.json` | `profiles/<name>/hooks/` + registration in `profiles/<name>/settings.json` |
| Output style | `base/output-styles/` (deployed to every profile) | `"outputStyle"` in `profiles/<name>/settings.json` (which one is on) |

A rule that only makes sense for work — an approval gate for infrastructure commands, a company review checklist — goes in `profiles/work/rules/`. Putting it in `base/rules/` loads it into every personal session too.

### Hooks

A [hook](https://code.claude.com/docs/en/hooks) is a script Claude Code runs at a fixed point, such as before a tool call. A rule asks the model to behave; a hook enforces it, so use one when a rule keeps being missed. It takes two parts:

1. **The script.** Put it in `base/hooks/` for every profile or `profiles/<name>/hooks/` for one. `scripts/deploy-hooks.sh` copies the top-level files of both into the home's `hooks/` and makes `.sh` files executable. Subdirectories are skipped, which is why `base/hooks/examples/` never deploys.
2. **The registration.** Add a `hooks` block to `base/settings.json` or the profile's `settings.json`, pointing at `{{CLAUDE_DIR}}/hooks/<script>`. `base/hooks/examples/block-env-reads.sh` shows both halves in its header.

Deploy verifies that every script a registration names exists and is executable, and fails the deploy when one is missing. It does not prune: a hook you delete from this repo stays in the deployed `hooks/` directory, unregistered and inert, until you delete it there by hand.

Every hook that runs on each prompt adds its output to every turn, and `tests/resident-budget.test.sh` counts it. Prefer hooks that stay silent unless they block something.

### Output styles and writing rules

An [output style](https://code.claude.com/docs/en/output-styles) becomes part of Claude Code's system prompt. That makes it a stronger place for rules about how a reply is shaped (length, what comes first, how it ends) than a rule file, which arrives as context. Styles live in `base/output-styles/` and deploy to every profile; a profile turns one on with `"outputStyle": "<name>"` in its `settings.json`. None is on by default.

A style can pull in another file with a marker on its own line, `<!-- include: base/style-pointer.md -->`. Deploy replaces the line with that file's contents, so text that also lives elsewhere keeps one source.

Prose rules (word choice, voice, commit messages) live once in `base/writing-rules.md`. Deploy copies it into every home's `rules/`, the one place a main session and its subagents both read, and Codex gets it as the `Voice` section of `AGENTS.md`. The example style points at it instead of repeating it, because a second copy costs tokens on every session and drifts. Subagents never see the output style, so anything a subagent must follow belongs in a rule.

## Adding the Other Tool With an LLM

If you already use one tool, you do not need a translation script. Claude Code and Codex CLI use different config shapes, so the goal is not a one-to-one file copy. Ask an LLM to preserve behavior by moving each concern into this repo's source layout, then let `./sync.sh` render the right files for each enabled tool.

Use this mapping when reviewing the migration:

| Behavior | Source file | Claude output | Codex output |
|---|---|---|---|
| Core instructions | `base/CLAUDE.md` | `~/.claude/CLAUDE.md` | compiled into `~/.codex/AGENTS.md` |
| Topic rules | `base/rules/`, `claude/rules/`, `profiles/<profile>/rules/` | `~/.claude/rules/` | compiled into `~/.codex/AGENTS.md` |
| Profile instructions | `profiles/<profile>/CLAUDE.md.append` | appended to `~/.claude/CLAUDE.md` | compiled into `~/.codex/AGENTS.md` |
| Codex-only instructions | `profiles/<profile>/AGENTS.md.append`, `codex/instructions.md` | not used | compiled into `~/.codex/AGENTS.md` |
| MCP servers | `base/mcp-servers-base.json`, `profiles/<profile>/mcp-servers.json` | merged into `~/.claude.json` | converted into `~/.codex/config.toml` |
| Custom skills | `claude/skills/<name>/SKILL.md` | `~/.claude/skills/` | `~/.codex/skills/` |
| Codex settings/plugins | `codex/config-base.toml` | not used | base of `~/.codex/config.toml` |

### Claude Code to Codex CLI

```text
I already use Claude Code and want to add Codex CLI with the same practical behavior.

Use this agentfiles repo as the source of truth. Claude and Codex config files are different, so do not try to copy files one-to-one. Preserve behavior by moving each concern into the right source file.

Inspect my existing Claude config if present:
- ~/.claude/CLAUDE.md
- ~/.claude/rules/
- ~/.claude/settings.json
- ~/.claude.json
- ~/.claude/skills/

Move shared instructions into base/CLAUDE.md.
Move topic-specific standards into base/rules/ or claude/rules/.
Move profile-specific instructions into profiles/<profile>/CLAUDE.md.append or profiles/<profile>/rules/.
Move MCP servers into base/mcp-servers-base.json or profiles/<profile>/mcp-servers.json.
Move reusable skills into claude/skills/<name>/SKILL.md.
Keep Codex-only settings minimal in codex/config-base.toml.
Do not edit ~/.claude/ or ~/.codex/ directly.
Do not commit secrets, private URLs, account IDs, or generated backups.
Run ./sync.sh and ./status.sh when done.
```

### Codex CLI to Claude Code

```text
I already use Codex CLI and want to add Claude Code with the same practical behavior.

Use this agentfiles repo as the source of truth. Claude and Codex config files are different, so do not try to copy files one-to-one. Preserve behavior by moving each concern into the right source file.

Inspect my existing Codex config if present:
- ~/.codex/AGENTS.md
- ~/.codex/config.toml
- ~/.codex/skills/

Separate shared instructions from Codex-only settings.
Move shared instructions into base/CLAUDE.md.
Move topic-specific standards into base/rules/ or claude/rules/.
Move profile-specific instructions into profiles/<profile>/CLAUDE.md.append or profiles/<profile>/rules/.
Move MCP servers from config.toml into base/mcp-servers-base.json or profiles/<profile>/mcp-servers.json.
Move reusable skills into claude/skills/<name>/SKILL.md.
Move Codex-only settings and plugin configuration into codex/config-base.toml.
Do not edit ~/.claude/ or ~/.codex/ directly.
Do not commit secrets, private URLs, account IDs, or generated backups.
Run ./sync.sh and ./status.sh when done.
```

## Adding a New Rule

1. Create a new `.md` file in the appropriate `rules/` directory
2. Run `./sync.sh`
3. The file automatically appears in `~/.claude/rules/` (and in AGENTS.md for Codex) — no script changes needed

Name the file after its topic: `python.md`, `api-design.md`, `git-workflow.md`.

## Adding a New Profile

The repo ships with `work` and `personal`, but you can create any profiles you need:

1. Create a new directory under `profiles/` (e.g., `profiles/freelance/`)
2. Add at minimum:
   - `CLAUDE.md.append` — Profile-specific instructions (can be empty)
   - `mcp-servers.json` — Profile-specific MCP servers (use `{}` for none)
   - `skills.txt` — Skill allowlist (one skill name per line; `@include <profile>` inherits another profile's list)
3. Optionally add:
   - `rules/` — Profile-specific rules
   - `AGENTS.md.append` — Codex-specific additions (appended after compiled AGENTS.md)
4. The shell scripts (`install.sh`, `switch-profile.sh`) auto-detect profiles from directory names

## Removing Things You Don't Need

The example files that ship with this repo are just that — examples. Feel free to:
- Delete any rule file that doesn't match your workflow
- Clear out the example content in `base/CLAUDE.md` and start fresh
- Remove entire example profiles and create your own
- Add shared MCP servers to `base/mcp-servers-base.json` if you want them available in every profile
- Remove the `codex/` directory entirely if you don't use Codex CLI

The scripts don't depend on any specific file content. They just merge whatever is there.

## Overriding Base Rules in a Profile

If a profile's `rules/` directory contains a file with the same name as a base rule, the profile version wins. For example:

- `base/rules/documentation.md` says "docs live in `docs/`"
- `profiles/work/rules/documentation.md` says "docs live in the company wiki"

When the work profile is active, the wiki version is deployed. When personal is active, the base version is used. The same override logic applies to `claude/rules/` — a profile rule with the same filename replaces it.

## Codex-Specific Customization

### config-base.toml

`codex/config-base.toml` contains Codex CLI settings such as approval mode, model defaults, and optional plugin marketplace configuration. These are deployed as the base of `~/.codex/config.toml`, with MCP server sections appended.

Its `[agents.*]` tables define subagent roles (explorer, worker, reviewer), so a session can hand work to a role with its own reasoning effort, and its own model once you set one, instead of inheriting the driver's. Each role's settings live in `codex/agents/<role>.toml`, deployed to `~/.codex/agents/`. The factory-zero profile gets none of this: `scripts/deploy-codex-minimal.sh` keeps only the engine settings and `[history]`.

### AGENTS.md Compilation

Codex has no rules directory — all instructions are compiled into a single `~/.codex/AGENTS.md`. The compile script assembles it from:
1. `codex/instructions.md` (Codex-specific preamble)
2. `base/CLAUDE.md`, then `base/writing-rules.md` as the `Voice` section, then the profile's `CLAUDE.md.append`
3. All effective rules (base → claude → profile, with overrides)
4. Skill metadata (lightweight index, not full skill bodies)
5. Profile `AGENTS.md.append` (if present)

## Variable Substitution

Two placeholders are replaced at deploy time in settings and MCP server files:

- `{{CLAUDE_DIR}}` becomes the Claude home being deployed (`~/.claude`, or `~/.claude-work` for a second account). Use it for hook commands, so each home runs its own copy.
- `{{HOME}}` becomes your home directory.

`{{CLAUDE_DIR}}` is replaced first everywhere. Codex has no home directory of its own to name, so its MCP servers get `{{HOME}}` only. To add a placeholder, extend the `sed` calls in `scripts/deploy-profile.sh`, `scripts/deploy-factory-zero.sh` and `scripts/merge-settings.sh`, which all use the same order.
