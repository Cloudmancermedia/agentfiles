# Codex CLI — Tool-Specific Instructions

You are running inside OpenAI's Codex CLI. The instructions below are shared across multiple AI coding tools and are written in tool-neutral language. Where they reference configuration files, rules, or session mechanics, the Codex equivalents are:

| Concept | Codex equivalent |
|---------|-----------------|
| Instructions file | `~/.codex/AGENTS.md` (this file) |
| Rules directory | N/A — all instructions are compiled into this file |
| Skills directory | `~/.codex/skills/` |
| MCP servers | `~/.codex/config.toml` `[mcp_servers]` tables |
| Plugins | `~/.codex/config.toml` `[marketplaces]` and `[plugins]` tables |
| Settings | `~/.codex/config.toml` |

## Codex-Specific Behavior

- This repository aims for Claude Code and Codex CLI parity: the same shared instructions, profile context, rules, custom skills, plugins, and MCP servers should be available to both tools after `./sync.sh` or `./switch-profile.sh`.
- When these instructions reference "rules files" or "auto-loaded rules," understand that in Codex all rule files are compiled into this single AGENTS.md file as sections below.
- References to `CLAUDE.md` in shared instructions refer to this file (AGENTS.md) in your context.
- References to prompt cache, compaction, or other Claude Code-specific session mechanics should be adapted to Codex's closest equivalent when one exists, and ignored when no Codex equivalent exists.
- **Skills:** When instructions say "invoke the `<name>` skill," use the matching installed Codex skill from `~/.codex/skills/`. Custom skills are synced from `claude/skills/*` to both Claude Code and Codex; AGENTS.md includes only a lightweight skill index, not full skill bodies.
- Follow the same coding standards, testing strategy, and documentation practices defined in the shared sections below.
