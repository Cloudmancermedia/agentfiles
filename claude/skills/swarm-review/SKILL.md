---
name: swarm-review
description: Use when a deep, multi-perspective code review is needed before opening a PR. Triggers on "swarm review", "deep review", "thorough review", or when changes are complex enough to warrant more than automated review. This is a pre-PR quality gate, not a replacement for the automated PR review bot.
---

# Swarm Review

Six-persona deep review of the current branch's changes. Each persona examines the diff through a different lens, producing findings with severity, evidence, and concrete fixes.

## When to Use

- Complex PRs touching multiple subsystems
- Changes to critical paths (auth, billing, data pipelines)
- Architectural changes or new patterns being introduced
- When the automated PR review bot isn't sufficient depth
- User explicitly requests a deep review before opening a PR

This is **not** part of the standard PR workflow. It is invoked explicitly when the user wants a thorough pre-PR analysis.

## Setup

1. Identify the base branch (usually `origin/main`). Run `git fetch origin main`.
2. Get the full diff: `git diff origin/main...HEAD`
3. Identify all changed files: `git diff --name-only origin/main...HEAD`
4. Review each changed file in full context (not just the diff hunks — personas need surrounding code to assess architecture, consistency, and edge cases).

## The Six Personas

Dispatch each persona as a parallel subagent reviewing the same diff. Each operates independently.

### 1. Correctness & Edge Cases
- Off-by-one errors, null/undefined paths, boundary conditions
- Input validation gaps, type coercion issues
- Error handling paths that silently fail or swallow errors
- Logic that works for the happy path but breaks on edge inputs

### 2. UX / Behavior Regression
- User-visible behavior changes (intentional or accidental)
- Loading states, error states, empty states
- Accessibility regressions
- Breaking changes to API contracts or response shapes

### 3. Architecture & Separation of Concerns
- Layer violations (business logic in handlers, infrastructure in domain)
- Coupling that makes future changes harder
- Responsibilities in the wrong place
- Missing or misused abstractions

### 4. Performance & Scalability
- N+1 queries, unbounded loops, missing pagination
- Memory allocation patterns (large arrays, retained closures)
- Cold start impact (new imports, initialization cost)
- Operations that scale linearly when they should be constant

### 5. Concurrency / State Safety
- Race conditions between async operations
- Shared mutable state without synchronization
- Event ordering assumptions that may not hold
- DynamoDB conditional writes that should be atomic but aren't

### 6. Codebase Consistency & Maintainability
- Patterns that diverge from established codebase conventions
- Naming inconsistencies with surrounding code
- Missing or incorrect types
- Code that a future reader would misunderstand

## Finding Format

Each persona produces findings in this format:

```markdown
### [Persona Name]

#### [Severity] — [One-line title]
**Evidence:** [Quote the specific code snippet or reference the logic]
**Why it matters:** [Risk, user impact, or long-term cost]
**Fix:** [Concrete patch-style replacement or exact change]
**Tests:** [1-2 targeted tests to validate the fix]
```

**Severity levels:**
- **Blocker** — Must fix before merge. Incorrect behavior, data loss risk, security issue.
- **Major** — Should fix before merge. Significant quality issue, performance problem, or architectural concern.
- **Minor** — Fix if time allows. Small improvement, minor inconsistency.
- **Nit** — Optional. Style preference, minor naming suggestion.

## Constraints

- Review only the current branch's changes (diff against base), not the entire codebase.
- Assume production-level standards.
- Flag hidden assumptions — code that works because of an undocumented invariant.
- Identify race conditions or async hazards if applicable.
- Ignore cosmetic formatting unless it affects clarity or readability.
- Prefer solutions that are explicit, testable, and predictable.

## Output

After all personas complete, consolidate into a single report:

1. **Summary** — Total findings by severity (e.g., "1 Blocker, 3 Major, 5 Minor, 2 Nit")
2. **Blockers first** — All blocker findings at the top, regardless of persona
3. **Then by persona** — Remaining findings grouped by persona
4. **Recommendation** — "Ready to open PR", "Fix blockers first", or "Consider rearchitecting [specific area]"

Present the report and ask the user how they want to proceed before making any changes.
