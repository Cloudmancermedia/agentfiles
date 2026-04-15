# claudefiles

Manage [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration across multiple devices and profiles.

## Why This Exists

If you use Claude Code for both work and personal projects, you probably want different rules for each — stricter conventions, different MCP servers, different coding standards. And if you work across multiple machines, keeping those rules in sync becomes a chore.

This project gives you a single Git repository that holds all of your Claude Code configuration, organized into profiles. Clone it on any machine, run one command, and your rules are deployed. Switch between work and personal with another command. Edit a rule in one place, push, pull on the other machine — done.

## What This Is

A lightweight framework for keeping your Claude Code configuration (CLAUDE.md, rules files, MCP servers, settings) in a Git repository so you can:

- **Sync across devices** — Clone on a new machine, run one command, done
- **Switch between profiles** — Work and personal accounts with different rules and tools
- **Share a base, customize per profile** — Common preferences stay in sync; profile-specific additions layer on top

The scripts handle merging, deploying, and switching. You focus on writing the configuration.

## What This Is NOT

- **Not a shell configurator.** This tool does not touch `.zshrc`, `.bashrc`, `.profile`, or any shell configuration. It exclusively manages files in `~/.claude/` and `~/.claude.json`.
- **Not prescriptive.** The example files show one way to use this. Delete them and write your own — the scripts don't care about content, only structure.

## ⚠️ Security Warning

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

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `jq` — JSON processor (`brew install jq` on macOS)
- `git`

### Setup

```bash
# 1. Fork this repo on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/claudefiles.git ~/claudefiles
cd ~/claudefiles

# 2. Customize the example files (see "How It Works" below)

# 3. Install — deploys configuration and sets your default profile
./install.sh
```

### Daily Use

```bash
# Pull latest config and reapply (one command does everything)
cd ~/claudefiles && ./sync.sh

# Switch between profiles
./switch-profile.sh work
./switch-profile.sh personal

# Check current state
./status.sh
```

## How It Works

### The Pattern

Everything follows one rule: **base configuration is shared, profile configuration extends it.**

```
base/CLAUDE.md  +  profiles/work/CLAUDE.md.append   →  ~/.claude/CLAUDE.md
base/rules/*.md +  profiles/work/rules/*.md          →  ~/.claude/rules/
base/mcp-servers-base.json + profiles/work/mcp-servers.json → ~/.claude.json (mcpServers)
base/settings.json                                    →  ~/.claude/settings.json
```

When you run `./sync.sh`, the scripts:
1. Pull the latest Git changes
2. Concatenate `base/CLAUDE.md` + the active profile's `CLAUDE.md.append`
3. Copy base rules files, then overlay profile rules files (same-name files override)
4. Merge base + profile MCP server configs (resolving `{{HOME}}` to your actual home directory)
5. Copy settings

### Where to Put Things

| It applies to... | Put it in... |
|---|---|
| All profiles | `base/CLAUDE.md` or `base/rules/<topic>.md` |
| Only one profile | `profiles/<name>/CLAUDE.md.append` or `profiles/<name>/rules/<topic>.md` |

**CLAUDE.md** is for core behavioral instructions (how Claude should think and communicate).
**Rules files** are for domain-specific standards (TypeScript style, testing philosophy, API conventions).

There's no enforced boundary — organize however makes sense to you. The only difference is structural: CLAUDE.md gets concatenated, rules files are individual files that get copied.

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

## This Repo Is Your Source of Truth

The intended workflow is:

1. **Edit files in this repo** — not in `~/.claude/` directly
2. **Run `./sync.sh`** to deploy changes locally
3. **Commit and push** so other machines can pull the update
4. **On the other machine:** `cd ~/claudefiles && ./sync.sh`

Direct edits to `~/.claude/` get overwritten on the next sync. That's by design — this repo is the durable, portable record.

If you include the `base/rules/config-management.md` rule (or write your own version of it), Claude itself will learn to edit this repo instead of `~/.claude/` when you ask it to change your configuration.

## Repository Structure

```
claudefiles/
├── base/                           # Shared config (all profiles)
│   ├── CLAUDE.md                   # Core instructions for Claude
│   ├── rules/                      # Shared rules (auto-loaded by Claude Code)
│   │   ├── api-design.md           # Example: REST API conventions
│   │   ├── typescript.md           # Example: TypeScript standards
│   │   ├── testing.md              # Example: Testing strategy
│   │   └── ...                     # Add your own .md files here
│   ├── mcp-servers-base.json       # MCP servers for all profiles
│   └── settings.json               # Claude Code settings
│
├── profiles/
│   ├── work/                       # Example: Work profile
│   │   ├── CLAUDE.md.append        # Work-specific instruction additions
│   │   ├── rules/                  # Work-specific rules
│   │   ├── mcp-servers.json        # Work-specific MCP servers
│   │   └── account.txt             # Claude account email hint
│   │
│   └── personal/                   # Example: Personal profile
│       ├── CLAUDE.md.append        # Personal-specific additions
│       ├── rules/                  # Personal-specific rules
│       ├── mcp-servers.json        # Personal-specific MCP servers
│       └── account.txt             # Claude account email hint
│
├── scripts/                        # Internal helper scripts
│   ├── deploy-rules.sh             # Deploys rules to ~/.claude/rules/
│   ├── merge-settings.sh           # Merges MCP servers + settings
│   └── backup-current.sh           # Backs up config before changes
│
├── local/                          # Machine-specific state (gitignored)
│
├── docs/
│   └── customization.md            # Detailed customization guide
│
├── install.sh                      # First-time setup
├── switch-profile.sh               # Switch profile + remind to re-login
├── sync.sh                         # Pull latest + reapply everything
├── status.sh                       # Show current state
├── LICENSE                         # MIT
└── CONTRIBUTING.md
```

## Commands

| Command | What It Does |
|---------|--------------|
| `./install.sh` | First-time setup — choose a default profile and deploy config |
| `./sync.sh` | Pull latest from Git + reapply everything |
| `./switch-profile.sh <name>` | Switch to a different profile (backs up first) |
| `./status.sh` | Show current profile, sync status, active MCP servers and rules |

## Adding More Profiles

The repo ships with `work` and `personal`, but you can create any profiles:

1. `mkdir -p profiles/freelance/rules`
2. Add `account.txt`, `CLAUDE.md.append`, `mcp-servers.json` (see existing profiles for the pattern)
3. `./switch-profile.sh freelance`

The scripts auto-detect profiles from directory names.

## Troubleshooting

**Changes not appearing?** Run `./sync.sh` — edits to this repo don't take effect until synced.

**Stale rules from a previous profile?** Sync clears `~/.claude/rules/` before redeploying, so this shouldn't happen. Run `./sync.sh` to fix.

**Wrong Claude account?** Run `./switch-profile.sh <profile>` — it reminds you to re-login.

**Merge conflicts?** `git pull --rebase`, resolve conflicts, `git push`, then `./sync.sh`.

## License

MIT — see [LICENSE](LICENSE).
