# Customization Guide

This document covers how to make claudefiles your own after forking.

## The Core Pattern

Everything in this repo follows one rule: **base configuration is shared across all profiles, profile-specific configuration extends it.**

```
base/CLAUDE.md + profiles/<profile>/CLAUDE.md.append → ~/.claude/CLAUDE.md
base/rules/*.md + profiles/<profile>/rules/*.md       → ~/.claude/rules/
base/mcp-servers-base.json + profiles/<profile>/mcp-servers.json → ~/.claude.json
```

When you run `./sync.sh`, the scripts merge these layers and deploy the result to `~/.claude/`.

## Where to Put Things

Ask yourself: **"Does this apply to all my profiles, or just one?"**

| It applies to... | Put it in... |
|---|---|
| All profiles | `base/CLAUDE.md` or `base/rules/<topic>.md` |
| Only work | `profiles/work/CLAUDE.md.append` or `profiles/work/rules/<topic>.md` |
| Only personal | `profiles/personal/CLAUDE.md.append` or `profiles/personal/rules/<topic>.md` |

### CLAUDE.md vs Rules Files

- **CLAUDE.md** — Core behavioral instructions. Things like "be concise", "always verify before claiming done", "prefer boring solutions." These are high-level principles that apply broadly.
- **Rules files** — Domain-specific standards. Things like "use 2-space indentation in TypeScript", "follow REST conventions for APIs", "test with Vitest." These are focused on a specific topic.

There's no strict boundary — use whatever organization makes sense to you. The only structural difference is that CLAUDE.md content gets concatenated (base + profile append), while rules files are individual files that get copied into `~/.claude/rules/`.

### MCP Servers

MCP server configuration follows the same base + profile merge pattern:
- `base/mcp-servers-base.json` — Servers you want available in all profiles
- `profiles/<profile>/mcp-servers.json` — Servers only needed for a specific profile

Use `{{HOME}}` as a placeholder for your home directory — the sync script resolves it at deploy time so the same config works on different machines.

## Adding a New Rule

1. Create a new `.md` file in the appropriate `rules/` directory
2. Run `./sync.sh`
3. The file automatically appears in `~/.claude/rules/` — no script changes needed

Name the file after its topic: `python.md`, `api-design.md`, `git-workflow.md`. Claude Code loads all `.md` files from the rules directory.

## Adding a New Profile

The repo ships with `work` and `personal`, but you can create any profiles you need:

1. Create a new directory under `profiles/` (e.g., `profiles/freelance/`)
2. Add at minimum:
   - `account.txt` — Email hint for the Claude account to use
   - `CLAUDE.md.append` — Profile-specific instructions (can be empty)
   - `mcp-servers.json` — Profile-specific MCP servers (use `{}` for none)
3. Optionally add a `rules/` subdirectory with profile-specific rules
4. The shell scripts (`install.sh`, `switch-profile.sh`) auto-detect profiles from directory names

## Removing Things You Don't Need

The example files that ship with this repo are just that — examples. Feel free to:
- Delete any rule file that doesn't match your workflow
- Clear out the example content in `base/CLAUDE.md` and start fresh
- Remove entire example profiles and create your own
- Gut `base/mcp-servers-base.json` if you don't use those servers

The scripts don't depend on any specific file content. They just merge whatever is there.

## Overriding Base Rules in a Profile

If a profile's `rules/` directory contains a file with the same name as a base rule, the profile version wins. For example:

- `base/rules/testing.md` says "prefer Vitest"
- `profiles/work/rules/testing.md` says "use Jest (company standard)"

When the work profile is active, the Jest version is deployed. When personal is active, the Vitest version is used.

## Variable Substitution

The merge script replaces `{{HOME}}` with your actual home directory. This is the only variable currently supported, but it's the main one that varies across machines.

If you need additional variables, edit `scripts/merge-settings.sh` — the substitution is a single `sed` command that's easy to extend.
