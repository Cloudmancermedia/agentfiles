# Skill Template

This template shows how to create a custom skill for Claude Code (and Codex CLI via sync).

## File Structure

Each skill lives in its own directory under `claude/skills/`:

```
claude/skills/
  your-skill-name/
    SKILL.md          # The skill definition (required)
```

After `./sync.sh`, skills are deployed to:
- Claude Code: `~/.claude/skills/your-skill-name/SKILL.md`
- Codex CLI: `~/.codex/skills/your-skill-name/SKILL.md`

## SKILL.md Format

Every SKILL.md starts with YAML frontmatter, then the skill body:

```yaml
---
name: your-skill-name
description: >
  One paragraph describing WHEN this skill should be triggered.
  Be specific about trigger phrases ("deep review", "audit to-dos")
  so the agent knows when to invoke it automatically.
---
```

The body is freeform Markdown. Effective patterns include:

- **When to Use** — Bullet list of scenarios
- **Setup** — What context to gather before starting
- **Steps** — The actual workflow (numbered or sectioned)
- **Output Format** — What the skill produces
- **Constraints** — Guardrails and limitations
- **Red Flags — STOP** — Conditions where the agent should halt

## Tips for Writing Skills

1. **Be specific about triggers.** Vague descriptions ("use for code tasks") won't activate reliably. Name the exact phrases or situations.
2. **Include output format.** If the skill produces a report, show the template. Agents follow structure better than prose instructions.
3. **Add stop conditions.** Skills that modify files should have explicit "wait for confirmation" checkpoints.
4. **Keep skills single-purpose.** One skill per workflow. If a skill has two unrelated sections, split it into two skills.
5. **Test with both tools.** Skills are synced to both Claude Code and Codex — verify the instructions work in both contexts.

## Example

See `claude/skills/swarm-review/SKILL.md` for a complete working example that demonstrates the multi-agent dispatch pattern.
