<!-- EXAMPLE RULE: Context Window Management
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers Claude Code prompt cache behavior, session length
  guidelines, and memory management. Useful if you want Claude to be
  efficient with its context window. -->

# Context Window and Prompt Cache Management

## How the System Prompt Cache Works
- System prompt sections are memoized and cached until `/clear` or `/compact`.
- Volatile content (content that changes every turn) breaks the prompt cache and increases latency and token usage.
- Hooks that inject `<system-reminder>` content on every tool call add up — each one is additional context that may invalidate cached prompt sections.
- Compaction triggers SessionStart hooks to re-fire, which re-injects all startup content.

## Guidelines

### Prefer On-Demand Over Always-Injected
- When dynamic context is needed, prefer tools that the model calls on-demand rather than hooks that inject on every turn.
- Do not suggest adding new hooks that inject volatile or frequently-changing data into the conversation unless the benefit clearly outweighs the cache cost.

### Session Length
- Long sessions degrade quality through context compression. Session memory is capped at 12K tokens and compaction summarizes the oldest messages first.
- For complex multi-step work, prefer shorter focused sessions with explicit memory saves between them over one marathon session.
- When you notice earlier decisions being lost or repeated questions about things already discussed, suggest the user start a fresh session after saving key context to memory.

### Memory
- The auto-extraction system runs at the end of each query loop and deduplicates against existing memories.
- For critical project context that must survive across sessions, save to memory explicitly and early rather than relying on auto-extraction at session end — context that gets compressed away cannot be extracted.
- Four memory types exist: user, feedback, project, reference. Choose the most specific type.

### Subagent Dispatch
- Fresh agents for independent concerns (different files, different domain) to avoid anchoring on stale context.
- Continue existing agents (SendMessage) when the subtask shares heavy context with the parent.
- Git worktree isolation aligns with the fresh-agent pattern for independent implementation work.
