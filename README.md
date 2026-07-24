# agentfiles

Manage [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex CLI](https://github.com/openai/codex) configuration across multiple devices and profiles.

`agentfiles` is a template you copy into a repo of your own — public or private — to act as the single source of truth for managing Claude Code and Codex CLI configuration, profiles, MCP servers, rules, and skills across devices, while letting each tool receive its native generated format.

## Why This Exists

The instructions you give your coding agent are some of the most valuable text you write. They encode how you want code reviewed, which commands are safe to run, what your deploy process is, and which mistakes you are tired of correcting. Yet by default that text lives in exactly the wrong place.

Three problems follow from that:

**It lives in generated files nobody versions.** Your rules sit in `~/.claude/` and `~/.codex/` — untracked directories on one machine. There is no history, so you cannot see what you changed last month or roll back a change that made the agent worse. Reinstall the tool or get a new laptop and it's gone.

**Every tool wants a different format.** Claude Code reads `CLAUDE.md` and `rules/*.md`; Codex CLI reads a single compiled `AGENTS.md` and TOML settings. Maintaining the same guidance twice means the two copies drift, and you end up with an agent that behaves differently depending on which terminal you opened.

**One set of rules doesn't fit every context.** Work code needs stricter conventions, different MCP servers, and an approval gate before anything touches infrastructure. Personal projects need none of that. Keeping one config and editing it by hand as you switch contexts is how proprietary detail ends up in a personal project and how safety rails end up missing from a work one.

agentfiles puts all of it in one Git repository. You write each rule once in a plain Markdown file, mark whether it is shared or profile-specific, and run one command. The scripts compile and deploy the native format each tool expects. Because it's Git, every change is a diff you can review, revert, and pull onto another machine.

## Use Cases

### "A new model came out and I want to retune my rules for it"

Model behavior changes, and instructions tuned for the last one can actively hurt the new one. You want to experiment without losing what already works.

Two separate moves, because the model and the rules are separate layers.

**Point the account at the new model:**

```bash
vim homes/personal/settings.json   # "model": "<the new model>"
./sync.sh
```

**Then retune the rules for it**, in a throwaway profile so your working set stays intact:

```bash
cp -r profiles/personal profiles/experiment
# edit profiles/experiment/rules/ ...
./switch-profile.sh experiment
```

Work in it for a few days. If the new rules are worse, `./switch-profile.sh personal` puts you back — and because the model lives in the account layer, switching profiles never changes which model you are testing. That's what makes the comparison meaningful. Every version is a Git commit, so you can diff the two rule sets and keep only the parts that helped.

**Features used:** per-account settings, profiles, Git history.

### "I use my AI subscription on more than one machine and want them in sync"

You tune a rule on your laptop and then have to remember to make the same edit on your desktop. In practice you don't, and the two machines slowly diverge.

Edit in the repo, push, then pull on the other machine:

```bash
# Machine A
vim base/rules/testing.md
git commit -am "require a failing test before a bug fix" && git push

# Machine B
cd ~/agentfiles && ./sync.sh
```

`sync.sh` pulls and redeploys everything for whichever tools that machine has enabled. Each machine can have a different tool set and a different active profile — what syncs is the source, not the machine's local choices, which live in the gitignored `local/` directory.

**Features used:** `sync.sh`, base/profile layering, per-machine `local/` state.

### "I need different configuration for work and personal projects"

Work needs an approval gate before infrastructure commands, MCP servers pointing at internal systems, and your team's conventions. Personal projects need a faster, looser setup. You want the shared preferences in both without maintaining two copies.

Put shared rules in `base/rules/`, context-specific rules in `profiles/work/rules/` and `profiles/personal/rules/`. Deploying a profile layers base first, then that profile on top — Claude Code gets the files side by side in `~/.claude/rules/`, Codex gets them compiled into one `AGENTS.md`. Either way your writing-style rules apply everywhere while the AWS approval gate only loads under `work`.

```bash
./switch-profile.sh work      # strict conventions, internal MCP servers
./switch-profile.sh personal  # lighter setup
```

This is also the boundary that keeps proprietary material contained: nothing in `profiles/work/` reaches a personal session.

**Features used:** profiles, base/profile layering, per-profile MCP servers and skills.

### "I have two accounts for the same tool on one machine"

A work Claude account and a personal one, both on the same laptop. Logging out and back in to swap is tedious and loses your session.

agentfiles calls each config directory a **home**. Two homes run side by side, each with its own login, MCP servers, and bound profile:

```bash
bin/claude-home work      # ~/.claude-work, work account, work profile
bin/claude-home personal  # ~/.claude, personal account, personal profile
```

The logins don't collide because Claude Code namespaces its Keychain credential by config directory. `./status.sh` shows every home, which profile is bound to it, and which account is logged in.

A single home is the default; most machines never need a second. Setup is in [docs/multi-account.md](docs/multi-account.md).

**Features used:** multi-home support, `bin/claude-home`, `local/.homes` bindings.

## What This Is

A lightweight framework for keeping your Claude Code and Codex CLI configuration in a Git repository so you can:

- **Sync across devices** — Clone on a new machine, run one command, done
- **Switch between profiles** — Different rules, MCP servers, and skills per context
- **Run multiple accounts** — Two logins for the same tool on one machine, each with its own config
- **Share a base, customize per profile** — Common preferences stay in sync; profile-specific additions layer on top
- **Configure one or both tools** — Use Claude Code only, Codex CLI only, or both from the same source
- **Review and revert** — Every configuration change is a Git commit you can diff and roll back

The scripts handle merging, deploying, and switching. You focus on writing the configuration.

## What This Is NOT

- **Not a shell configurator.** This tool does not touch `.zshrc`, `.bashrc`, `.profile`, or any shell configuration. It exclusively manages files in `~/.claude/`, `~/.claude.json`, `~/.codex/`, and `~/.codex/config.toml`.
- **Not prescriptive.** The example files show one way to use this. Delete them and write your own — the scripts don't care about content, only structure.

## Before You Clone: Public Fork or Private Copy?

This repo becomes your source of truth — the place you edit configuration and push so your other machines can pull it. That means your own rules, skills, and MCP server definitions end up committed here. Decide where they live before you start, because one direction is hard to reverse.

### A public fork can never be made private

GitHub does not let you flip a fork of a public repo to private. From [GitHub's docs on repository visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility): *"Public forks are not made private."* If you later make your own repo private, existing forks stay public and are detached into their own network.

So if there is any chance your configuration will carry work material, do not start with a fork. Start with a private copy (Path A below).

### Which one is for you

| | Public fork | Private copy |
|---|---|---|
| Your config is entirely personal | Fine | Fine |
| You use these tools for work | **No** | Yes |
| You want to contribute changes back | Yes | Yes, via a fork alongside it |
| Everything you commit is publicly searchable | Yes | No |

### Why work usage forces a private copy

Agent configuration attracts proprietary detail faster than people expect. These are the things that show up in a real `base/` and `profiles/work/` directory:

- Rules naming internal services, repositories, or deploy processes
- Skills encoding a company workflow, runbook, or review checklist
- MCP servers pointing at internal endpoints — sometimes with a token in the config
- AWS profile names, account IDs, and role ARNs
- Ticket prefixes and project names from an employer's tracker
- Your work email address

> **Warning**
> Git history is permanent. Once you push to a public repo, that content is cloned, cached, and indexed by third parties. Deleting the file in a later commit does not remove it from history. Treat anything you have ever pushed publicly as public forever.

There is also a practical reason, separate from safety: work-specific rules and skills usually aren't portable to a public repo at all. They reference systems nobody outside your company can reach, so they are noise to every other reader. A private copy is where they belong.

If you want both, run two repos: a private one you actually use, and a public fork for changes you intend to contribute upstream.

**Whichever you pick, never commit:** API keys, tokens, or credentials; real email addresses (use `your-email@example.com`); AWS account IDs or ARNs. Prefer environment variables over hardcoded values, and add anything machine-specific to `.gitignore`.

## Quick Start

### Prerequisites

macOS and Linux. The scripts are plain `bash` and avoid GNU-only flags, so they run on macOS's stock bash 3.2 as well as on modern Linux.

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed (optional — at least one tool required)
- [Codex CLI](https://github.com/openai/codex) installed (optional — at least one tool required)
- `jq` — JSON processor (`brew install jq` on macOS, `apt install jq` on Debian/Ubuntu)
- `npm` — optional; required if your MCP servers use `npx`
- `git`

### Setup — Path A: private copy (recommended)

Use this if you work with anything proprietary. It gives you a private repo of your own, with the public repo wired up as `upstream` so you can still pull improvements.

```bash
# 1. On GitHub, create a new EMPTY private repository. Do not add a README,
#    .gitignore, or license — it has to be empty for the mirror push to work.
#    These examples call it `agentfiles-private`; name it whatever you like.

# 2. Bare-clone the public repo, then mirror-push it into your private one.
git clone --bare https://github.com/Cloudmancermedia/agentfiles.git
cd agentfiles.git
git push --mirror https://github.com/YOUR_USERNAME/agentfiles-private.git
cd ..
rm -rf agentfiles.git

# 3. Clone YOUR private repo to ~/agentfiles.
git clone https://github.com/YOUR_USERNAME/agentfiles-private.git ~/agentfiles
cd ~/agentfiles

# 4. Point `upstream` at the public repo so you can pull improvements later.
git remote add upstream https://github.com/Cloudmancermedia/agentfiles.git
git remote -v
#   origin    -> your private repo  (you push here)
#   upstream  -> the public repo    (you pull from here; never push to it)

# 5. Customize the example files (see "How It Works" below).

# 6. Install — choose your tools and default profile.
./install.sh
```

Steps 2 and 3 are GitHub's own [documented way to duplicate a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository). A mirror push copies the full history rather than creating a fork, which is exactly why the result can be private.

To pull later improvements from the public repo into your private one:

```bash
cd ~/agentfiles
git fetch upstream
git merge upstream/main
```

Expect merge conflicts in files you have customized — `base/CLAUDE.md`, the `profiles/` directories, and the MCP server JSON. That is normal: keep your version, take upstream's changes to the scripts.

### Setup — Path B: public fork

Use this only if your configuration will stay entirely personal. Remember you cannot convert it to private later.

```bash
# 1. Fork this repo on GitHub, then clone your fork.
git clone https://github.com/YOUR_USERNAME/agentfiles.git ~/agentfiles
cd ~/agentfiles

# 2. Add the public repo as `upstream` so you can pull improvements.
git remote add upstream https://github.com/Cloudmancermedia/agentfiles.git

# 3. Customize the example files (see "How It Works" below).

# 4. Install — choose your tools and default profile.
./install.sh
```

The installer asks which tools to configure on this machine:
1. Claude Code only
2. Claude Code + Codex CLI
3. Codex CLI only

Installs and profile switches do not back up your generated config, by design. A deploy is a deterministic re-run from this repo, so the way to recover a previous state is `git checkout` the config you want and `./sync.sh` again. Note that this covers configuration only — session history and app state under `~/.claude/` are user data agentfiles never writes or restores.

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

Settings add a third layer on top, because two things are being described and they change on different schedules:

- A **profile** is behavior — rules, skills, MCP servers, CLAUDE.md, output style. You swap these freely.
- An **account** (a Claude home) has engine settings that belong to the seat: which `model` it runs and what `effortLevel`. Those follow the account's plan, so switching profiles must not change them.

```
base/settings.json                  shared defaults
  -> profiles/<name>/settings.json  behavior for this profile
    -> homes/<label>/settings.json  engine settings for this account   (wins)
```

The home layer merges last and is keyed by home label, not profile name. On a single-home machine you can ignore it — the `homes/` files are optional. See [docs/multi-account.md](docs/multi-account.md#profiles-are-behavior-accounts-are-engine-settings).

The scripts deploy to different locations depending on which tools are enabled:

**Claude Code:**
```
base/CLAUDE.md + profile CLAUDE.md.append                 → ~/.claude/CLAUDE.md
base/rules/ + claude/rules/ + profile rules/              → ~/.claude/rules/
base/mcp-servers-base.json + profile mcp-servers.json     → ~/.claude.json (mcpServers)
base/settings.json + profile settings + homes/<label>/    → ~/.claude/settings.json
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
3. **For Claude Code:** Concatenate `base/CLAUDE.md` + the active profile's `CLAUDE.md.append`, copy rules (base + claude-specific + profile), merge MCP server configs, deploy skills, then merge settings in three layers — base, profile, then `homes/<label>/settings.json` last. Repeated once per home in `local/.homes`.
4. **For Codex CLI:** Compile `AGENTS.md` from instructions + CLAUDE.md + rules + skills, convert MCP server JSON to TOML, deploy skills

### Where to Put Things

| It applies to... | Put it in... |
|---|---|
| All profiles, all tools | `base/CLAUDE.md` or `base/rules/<topic>.md` |
| Claude Code and Codex (not base) | `claude/rules/<topic>.md` |
| Only one profile | `profiles/<name>/CLAUDE.md.append` or `profiles/<name>/rules/<topic>.md` |
| One Claude account, whatever profile it runs | `homes/<label>/settings.json` (`model`, `effortLevel`) |
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
├── homes/                              # Per-ACCOUNT settings, keyed by home label
│   ├── personal/settings.json         # model + effortLevel for the personal seat
│   └── work/settings.json             # model + effortLevel for the work seat
│                                      # Merged LAST, so a profile swap never
│                                      # changes an account's model. Optional.
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
