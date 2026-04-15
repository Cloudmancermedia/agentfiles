# Tool and Skill Usage

## MCP Tool Selection

### AWS Tools — Operational vs Reference
- **For live operations** (querying logs, checking alarms, viewing metrics): Use `cloudwatch` tools directly.
- **For table design and data modeling**: Use `dynamodb` tools directly.
- **For conceptual questions, documentation, or "how do I..."**: Use `aws-knowledge-mcp-server` to search reference docs.
- **For CDK constructs and shared helpers**: If your project has a shared constructs MCP server, prefer it over implementing custom patterns.
- Do not search reference docs when the user is asking for live operational data — use the operational tool.

### Library Documentation (Context7)
- Always use Context7 MCP tools when code generation, setup, configuration, or library/API documentation is needed.
- Automatically invoke `resolve-library-id` to find the correct library before using `get-library-docs`.
- Use Context7 proactively without waiting for explicit requests.
- Do not rely on training data for library APIs — check Context7 even for well-known libraries.

## Skill Invocation

### Cost Awareness
- Each invoked skill adds to the context window for that turn (typically 4-10 KB each).
- A full feature workflow can accumulate ~38 KB of skill content. Be selective.

### When to Skip Skills
- **Simple, isolated changes** (typo fixes, single-line updates, config tweaks): Skip skills entirely — just do the work.
- **Clear requirements with obvious approach**: Skip brainstorming and planning skills — proceed directly.
- **Quick bug fixes with obvious cause**: Skip systematic-debugging — fix it directly.
- **Adding tests to existing code**: Skip test-driven-development if the test structure is already established.

### When Skills Add Value
- **Ambiguous requirements or multiple valid approaches**: Use brainstorming to explore options.
- **Multi-file changes or architectural decisions**: Use writing-plans to design the approach.
- **Mysterious bugs with unclear root cause**: Use systematic-debugging for structured investigation.
- **New feature with no existing test patterns**: Use test-driven-development to establish the pattern.
- **Completing a feature branch**: Use finishing-a-development-branch for merge/PR decision.

### Avoid Stacking
- Do not invoke multiple heavy skills in the same turn when a lighter approach works.
- If a skill was already invoked earlier in the session for the same task, do not re-invoke it — refer back to the earlier output.
