# AI Tool Configuration Management

All Claude Code and Codex CLI configuration in this setup is managed through the dedicated `agentfiles` Git repository. This repo is the **single source of truth** for instructions, rules, custom skills, plugins, MCP server configs, and tool settings across machines and profiles.

## Rules

### Never Edit Generated Tool Config Directly
- **Never** make direct edits to generated files in `~/.claude/`, `~/.claude/rules/`, `~/.claude.json`, `~/.codex/AGENTS.md`, `~/.codex/config.toml`, `~/.codex/skills/`, or any other local deployed tool config path.
- All changes must be made in the `agentfiles` repository and deployed via `sync.sh`.
- Direct edits will be overwritten on the next sync and will not propagate to other machines.

### Locate the Repository First
- When asked to add, update, or remove a rule or config:
  1. Check if the current working directory is already the `agentfiles` repo
  2. If not, look for it at `~/agentfiles`
  3. If it cannot be found, **ask the user to locate it** — do not fall back to editing generated tool config directly
- Once located, make changes in the appropriate place:
  - **Base rules** (`base/rules/`): Apply to all profiles on all machines
  - **Claude-authored rules** (`claude/rules/`): Deploy to Claude Code and compile into Codex for parity
  - **Profile rules** (`profiles/<name>/rules/`): Apply only to a specific profile
  - **CLAUDE.md** (`base/CLAUDE.md`): Global instructions shared across profiles
  - **Profile CLAUDE.md** (`profiles/<name>/CLAUDE.md.append`): Profile-specific additions
  - **Custom skills** (`claude/skills/<name>/SKILL.md`): Source of truth for skills synced to both Claude Code and Codex
  - **Codex-specific config** (`codex/`): Codex-only preamble, TOML settings, and optional plugin marketplaces/plugin enablement

### Commit, Push, and Sync
- After making changes, always commit and push to the remote so other machines can pull the update.
- Run `sync.sh` to deploy the changes to the enabled local tools.

### Prefer Repo-Level Persistence Over Local Memories
- When the user asks to "remember" something that should apply across machines (rules, preferences, conventions, workflow instructions):
  - **Always** persist it as a rule file or CLAUDE.md update in the `agentfiles` repo
  - A local memory file may be saved **in addition** for immediate availability, but the repo is the durable, cross-machine record
- Local memories (`.claude/projects/*/memory/`) are machine-specific and do not sync — they are supplementary, not authoritative
- If the thing to remember is only relevant to a single machine or session, a local memory alone is fine
