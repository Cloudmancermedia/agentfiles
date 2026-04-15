# Claude Configuration Management

All Claude Code configuration (CLAUDE.md, rules files, settings, MCP server configs) is managed through a dedicated `claudefiles` Git repository. This repo is the **single source of truth** and is synced across multiple machines and profiles.

## Rules

### Never Edit ~/.claude/ Directly
- **Never** make direct edits to files in `~/.claude/`, `~/.claude/rules/`, `~/.claude.json`, or any other local Claude config path.
- All changes must be made in the `claudefiles` repository and deployed via `sync.sh`.
- Direct edits will be overwritten on the next sync and will not propagate to other machines.

### Locate the Repository First
- When asked to add, update, or remove a rule or config:
  1. Check if the current working directory is already the `claudefiles` repo
  2. If not, look for it at `~/claudefiles`
  3. If it cannot be found, **ask the user to locate it** — do not fall back to editing `~/.claude/` directly
- Once located, make changes in the appropriate place:
  - **Base rules** (`base/rules/`): Apply to all profiles on all machines
  - **Profile rules** (`profiles/<name>/rules/`): Apply only to a specific profile
  - **CLAUDE.md** (`base/CLAUDE.md`): Global instructions shared across profiles
  - **Profile CLAUDE.md** (`profiles/<name>/CLAUDE.md.append`): Profile-specific additions

### Commit, Push, and Sync
- After making changes, always commit and push to the remote so other machines can pull the update.
- Run `sync.sh` to deploy the changes to the local `~/.claude/` directory.

### Prefer Repo-Level Persistence Over Local Memories
- When the user asks to "remember" something that should apply across machines (rules, preferences, conventions, workflow instructions):
  - **Always** persist it as a rule file or CLAUDE.md update in the `claudefiles` repo
  - A local memory file may be saved **in addition** for immediate availability, but the repo is the durable, cross-machine record
- Local memories (`.claude/projects/*/memory/`) are machine-specific and do not sync — they are supplementary, not authoritative
- If the thing to remember is only relevant to a single machine or session, a local memory alone is fine
