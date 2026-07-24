# agentfiles

Manage [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex CLI](https://github.com/openai/codex) configuration across multiple devices and profiles.

`agentfiles` is a forkable source-of-truth repo for managing Claude Code and Codex CLI configuration, profiles, MCP servers, rules, and skills across devices, while letting each tool receive its native generated format.

## Why This Exists

If you use Claude Code or Codex CLI for both work and personal projects, you probably want different rules for each — stricter conventions, different MCP servers, different coding standards. And if you work across multiple machines, keeping those rules in sync becomes a chore.

This project gives you a single Git repository that holds all of your agent configuration, organized into profiles. Clone it on any machine, run one command, and your rules are deployed. Switch between work and personal with another command. Edit a rule in one place, push, pull on the other machine — done.

## What This Is

A lightweight framework for keeping your Claude Code and Codex CLI configuration in a Git repository so you can:

- **Sync across devices** — Clone on a new machine, run one command, done
- **Switch between profiles** — Work and personal accounts with different rules and tools
- **Share a base, customize per profile** — Common preferences stay in sync; profile-specific additions layer on top
- **Configure one or both tools** — Use Claude Code only, Codex CLI only, or both from the same source

The scripts handle merging, deploying, and switching. You focus on writing the configuration.

## What This Is NOT

- **Not a shell configurator.** This tool does not touch `.zshrc`, `.bashrc`, `.profile`, or any shell configuration. It exclusively manages files in `~/.claude/`, `~/.claude.json`, `~/.codex/`, and `~/.codex/config.toml`.
- **Not prescriptive.** The example files show one way to use this. Delete them and write your own — the scripts don't care about content, only structure.

## Security Warning

**This repository is designed to be your source of truth — the place you edit configuration and push to Git so other machines can pull it.** If you fork this publicly, be careful about what you commit.

**DO NOT commit:**
- Real email addresses (use `your-email@example.com` as a placeholder)
- API keys, tokens, or credentials
- Internal company URLs or proprietary information
- AWS account IDs, resource ARNs, or infrastructure details
- Anything you wouldn't want publicly searchable on GitHub

**If you work with sensitive configuration**, consider:
- Using a **private** fork or repository
- Adding sensitive files to `.gitignore`
- Using environment variables instead of hardcoded values

This is especially important if you're new to Git — once something is pushed to a public repo, it's in the Git history even if you delete it later. When in doubt, keep your fork private.

## Quick Start

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed (optional — at least one tool required)
- [Codex CLI](https://github.com/openai/codex) installed (optional — at least one tool required)
- `jq` — JSON processor (`brew install jq` on macOS)
- `npm` — optional; required if your MCP servers use `npx`
- `git`

### Setup

```bash
# 1. Fork this repo on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/agentfiles.git ~/agentfiles
cd ~/agentfiles

# 2. Customize the example files (see "How It Works" below)

# 3. Install — choose your tools and default profile
./install.sh
```

The installer asks which tools to configure on this machine:
1. Claude Code only
2. Claude Code + Codex CLI
3. Codex CLI only

Before install or profile switches overwrite generated files, current Claude Code and Codex CLI config is backed up under `~/.agentfiles-backups/<timestamp>/`.

### Daily Use

```bash
# Pull latest config and reapply (one command does everything)
cd ~/agentfiles && ./sync.sh

# Switch between profiles
./switch-profile.sh work
./switch-profile.sh personal

# Check current state
./status.sh
```

## How It Works

### The Pattern

Everything follows one rule: **base configuration is shared, profile configuration extends it.**

The scripts deploy to different locations depending on which tools are enabled:

**Claude Code:**
```
base/CLAUDE.md + profile CLAUDE.md.append                 → ~/.claude/CLAUDE.md
base/rules/ + claude/rules/ + profile rules/              → ~/.claude/rules/
base/mcp-servers-base.json + profile mcp-servers.json     → ~/.claude.json (mcpServers)
base/settings.json                                        → ~/.claude/settings.json
claude/skills/*/                                          → ~/.claude/skills/
```

**Codex CLI:**
```
codex/instructions.md + CLAUDE.md + rules + skills        → ~/.codex/AGENTS.md
codex/config-base.toml + MCP servers (JSON→TOML)          → ~/.codex/config.toml
claude/skills/*/                                          → ~/.codex/skills/
```

When you run `./sync.sh`, the scripts:
1. Pull the latest Git changes
2. Read which tools are enabled on this machine
3. **For Claude Code:** Concatenate `base/CLAUDE.md` + the active profile's `CLAUDE.md.append`, copy rules (base + claude-specific + profile), merge MCP server configs, deploy skills and settings
4. **For Codex CLI:** Compile `AGENTS.md` from instructions + CLAUDE.md + rules + skills, convert MCP server JSON to TOML, deploy skills

### Where to Put Things

| It applies to... | Put it in... |
|---|---|
| All profiles, all tools | `base/CLAUDE.md` or `base/rules/<topic>.md` |
| Claude Code and Codex (not base) | `claude/rules/<topic>.md` |
| Only one profile | `profiles/<name>/CLAUDE.md.append` or `profiles/<name>/rules/<topic>.md` |
| Codex-specific behavior | `codex/instructions.md` or `codex/config-base.toml` |
| Skills (both tools) | `claude/skills/<name>/SKILL.md` |

**CLAUDE.md** is for core behavioral instructions (how the agent should think and communicate).
**Rules files** are for domain-specific standards (TypeScript style, testing philosophy, API conventions).
**Skills** are reusable workflows that agents can invoke (code review, debugging, planning).

There's no enforced boundary — organize however makes sense to you. The only difference is structural: CLAUDE.md gets concatenated, rules files are individual files that get copied or compiled, skills are directories with a `SKILL.md` each.

### Adding the Other Tool

Claude Code and Codex CLI use different config shapes. This repo is not trying to make those files identical; it gives you one source layout that can render equivalent behavior into each tool.

Use this mapping when migrating:

| Behavior you want to preserve | Source file in this repo | Claude output | Codex output |
|---|---|---|---|
| Core instructions | `base/CLAUDE.md` | `~/.claude/CLAUDE.md` | compiled into `~/.codex/AGENTS.md` |
| Topic rules | `base/rules/`, `claude/rules/`, `profiles/<profile>/rules/` | `~/.claude/rules/` | compiled into `~/.codex/AGENTS.md` |
| Profile-specific instructions | `profiles/<profile>/CLAUDE.md.append` | appended to `~/.claude/CLAUDE.md` | compiled into `~/.codex/AGENTS.md` |
| Codex-only instructions | `profiles/<profile>/AGENTS.md.append` or `codex/instructions.md` | not used | compiled into `~/.codex/AGENTS.md` |
| MCP servers | `base/mcp-servers-base.json`, `profiles/<profile>/mcp-servers.json` | merged into `~/.claude.json` | converted into `~/.codex/config.toml` |
| Custom skills | `claude/skills/<name>/SKILL.md` | `~/.claude/skills/` | `~/.codex/skills/` |
| Codex settings/plugins | `codex/config-base.toml` | not used | base of `~/.codex/config.toml` |

If you already use Claude Code and want Codex CLI to behave the same, ask an LLM to migrate behavior into this repo as the source of truth, then enable Codex during `./install.sh`:

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

If you already use Codex CLI and want Claude Code to behave the same, use the same idea in reverse:

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

### Adding a Rule

1. Create a `.md` file in the appropriate `rules/` directory
2. Run `./sync.sh`
3. Done — no script changes needed

### Adding an MCP Server

Edit `base/mcp-servers-base.json` (shared) or `profiles/<name>/mcp-servers.json` (profile-specific), then `./sync.sh`.

Use `{{HOME}}` for paths that differ across machines:
```json
{
  "my-server": {
    "command": "npx",
    "args": ["my-mcp-server", "{{HOME}}/path/to/data"]
  }
}
```

For Codex CLI, MCP server JSON is automatically converted to TOML format during deployment — you only need to maintain the JSON files.

## Skills

Skills are reusable agent workflows — structured instructions that agents can invoke by name. Each skill lives in its own directory under `claude/skills/`:

```
claude/skills/
  swarm-review/
    SKILL.md            # Multi-agent code review workflow
  your-skill-name/
    SKILL.md            # Your custom skill
```

After `./sync.sh`, skills are deployed to both tools:
- Claude Code: `~/.claude/skills/<name>/SKILL.md`
- Codex CLI: `~/.codex/skills/<name>/SKILL.md`

To create a new skill, see `claude/skills/SKILL-TEMPLATE.md` for the format and conventions. The `swarm-review` skill is included as a working example.

## This Repo Is Your Source of Truth

The intended workflow is:

1. **Edit files in this repo** — not in `~/.claude/` or `~/.codex/` directly
2. **Run `./sync.sh`** to deploy changes locally
3. **Commit and push** so other machines can pull the update
4. **On the other machine:** `cd ~/agentfiles && ./sync.sh`

Direct edits to `~/.claude/` or `~/.codex/` get overwritten on the next sync. That's by design — this repo is the durable, portable record.

If you include the `claude/rules/config-management.md` rule (or write your own version of it), Claude itself will learn to edit this repo instead of `~/.claude/` when you ask it to change your configuration.

## Repository Structure

```
agentfiles/
├── base/                               # Shared config (all profiles)
│   ├── CLAUDE.md                       # Core instructions for the agent
│   ├── rules/                          # Shared rules (auto-loaded)
│   │   ├── documentation.md           # Example: where docs live
│   │   ├── tool-and-skill-usage.md    # Example: tool/skill selection
│   │   └── ...                        # Add your own .md files here
│   ├── mcp-servers-base.json          # MCP servers for all profiles
│   └── settings.json                  # Claude Code settings
│
├── claude/                             # Claude Code + Codex shared extras
│   ├── rules/                         # Rules deployed to both tools
│   │   ├── config-management.md       # Example: Config repo conventions
│   │   ├── context-management.md      # Example: Context window management
│   │   └── conversation-style.md      # Example: Response style preferences
│   └── skills/                        # Agent skills (both tools)
│       ├── SKILL-TEMPLATE.md          # How to create a new skill
│       └── swarm-review/              # Example: Multi-agent code review
│           └── SKILL.md
│
├── codex/                              # Codex CLI specific config
│   ├── instructions.md                # Codex-specific preamble for AGENTS.md
│   └── config-base.toml               # Base Codex TOML config
│
├── profiles/
│   ├── work/                          # Example: Work profile
│   │   ├── CLAUDE.md.append           # Work-specific instruction additions
│   │   ├── AGENTS.md.append           # Work-specific Codex additions
│   │   ├── rules/                     # Work-specific rules
│   │   ├── skills.txt                 # Skill allowlist (@include inherits)
│   │   └── mcp-servers.json           # Work-specific MCP servers
│   │
│   ├── personal/                      # Example: Personal profile
│   │   ├── CLAUDE.md.append           # Personal-specific additions
│   │   ├── AGENTS.md.append           # Personal-specific Codex additions
│   │   ├── rules/                     # Personal-specific rules
│   │   ├── skills.txt                 # Skill allowlist
│   │   └── mcp-servers.json           # Personal-specific MCP servers
│   │
│   └── factory-zero/                  # Example: deploys nothing (clean baseline)
│       └── factory-zero.flag
│
├── bin/
│   └── claude-home                    # Launch Claude against a specific home
│
├── scripts/                           # Internal helper scripts
│   ├── resolve-homes.sh              # Parses local/.homes (profile<->home table)
│   ├── deploy-profile.sh             # Deploys one profile into one home
│   ├── deploy-factory-zero.sh        # Tears a home down to nothing
│   ├── deploy-shared-skills.sh       # Materializes the shared skill store
│   ├── profile-skills.sh             # Resolves a profile's skill allowlist
│   ├── compile-agents-md.sh          # Compiles AGENTS.md for Codex
│   ├── deploy-claude-plugins.sh      # Deploys Claude Code plugins
│   ├── deploy-codex.sh               # Deploys Codex CLI configuration
│   ├── deploy-rules.sh               # Deploys rules to a home's rules/
│   ├── deploy-skills.sh              # Deploys skills to Codex
│   ├── verify-plugins.sh             # Reports plugin enable-state drift
│   ├── json-to-toml-mcp.sh           # Converts MCP JSON to TOML format
│   └── merge-settings.sh             # Merges MCP servers + settings
│
├── local/                             # Machine-specific state (gitignored)
│   └── .homes                         # Which profile deploys into which home
│
├── docs/
│   ├── customization.md              # Detailed customization guide
│   └── multi-account.md              # Adding a second account/home
│
├── install.sh                         # First-time setup (tool + profile selection)
├── switch-profile.sh                  # Rebind a home to a profile + redeploy
├── sync.sh                            # Pull latest + reapply everything
├── status.sh                          # Show homes and account state
├── LICENSE                            # MIT
└── CONTRIBUTING.md
```

## Commands

| Command | What It Does |
|---------|--------------|
| `./install.sh` | First-time setup — choose which tools to configure and set a default profile |
| `./sync.sh` | Pull latest from Git + reapply everything for enabled tools |
| `./switch-profile.sh [<home>] <name>` | Rebind a home to a profile and redeploy it |
| `./status.sh` | Show homes, bound profiles, logged-in accounts, MCP servers and rules |

## Adding More Profiles

The repo ships with `work` and `personal`, but you can create any profiles:

1. `mkdir -p profiles/freelance/rules`
2. Add `CLAUDE.md.append`, `AGENTS.md.append`, `mcp-servers.json`, `skills.txt` (see existing profiles for the pattern)
3. `./switch-profile.sh freelance`

The scripts auto-detect profiles from directory names. `AGENTS.md.append` is optional — only needed if you use Codex CLI and want profile-specific Codex instructions.

## Troubleshooting

**Changes not appearing?** Run `./sync.sh` — edits to this repo don't take effect until synced.

**Stale rules from a previous profile?** Sync clears `~/.claude/rules/` before redeploying, so this shouldn't happen. Run `./sync.sh` to fix.

**Wrong Claude account?** Run `./switch-profile.sh <profile>` — it reminds you to re-login.

**Merge conflicts?** `git pull --rebase`, resolve conflicts, `git push`, then `./sync.sh`.

**AGENTS.md not deploying to Codex?** Check that `codex` is in your enabled tools (`cat local/.enabled-tools`). If not, re-run `./install.sh` and select an option that includes Codex CLI.

**Codex config.toml issues?** The TOML is generated from `codex/config-base.toml` plus MCP servers converted from JSON. Check `codex/config-base.toml` for syntax errors. MCP server conversion requires `jq`.

**Skills not appearing?** Skills must follow the directory structure `claude/skills/<name>/SKILL.md`. Run `./sync.sh` and check that the skill directory contains a `SKILL.md` file.

## License

MIT — see [LICENSE](LICENSE).
