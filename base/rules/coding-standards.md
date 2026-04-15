<!-- EXAMPLE RULE: Coding Standards
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers ESLint discipline, shared constants, error handling
  philosophy, bug fix verification, and security practices. These are broadly
  applicable — adapt the specifics to your codebase. -->

# Coding Standards

## ESLint Ignore Comments (CRITICAL)
- **NEVER** add an `eslint-disable` comment (inline or file-level) without first:
  1. Explicitly raising it with the user — explain which rule and where
  2. Providing a compelling justification that there is genuinely no other path forward
- Before raising it, re-examine the code and confirm the issue cannot be resolved with a proper type, refactor, or minor code change
- The bar is: "There is no way to satisfy this rule without making the code worse"
- If you cannot meet that bar, fix the code properly instead

## Shared Constants Over Hardcoded Values (CRITICAL)
- **Before defining any literal value** (string, number, URL, model ID, config key, etc.), search the codebase for existing references to that same value.
- **If the value is already defined elsewhere**, import and reuse the existing definition. Never duplicate it.
- **If the value is new but will be referenced in more than one place** (or reasonably could be in the future — e.g., an API model ID used in both runtime code and IAM policy, a table name used in both CDK and Lambda, an event source used in both producer and consumer), extract it into a shared constant immediately. Do not hardcode it in multiple locations and plan to "clean it up later."
- **The test for extraction**: If changing this value would require updating more than one file, it must be a shared constant. A single source of truth prevents drift where one reference gets updated and another doesn't — which causes bugs that are hard to detect because each location looks correct in isolation.
- **Where to put shared constants**: Use the project's established patterns for shared constants (e.g., a `consts/` directory, a shared module, or an exported constant from the defining module). The constant should live closest to the code that owns the concept.

## Error Handling and Failure Surfacing (CRITICAL)

### General Principles
- Handle errors gracefully with meaningful messages
- Use try-catch blocks for async operations
- Log errors with sufficient context for debugging (use project-specific loggers if available — they may have special requirements like awaiting error logs)
- Provide user-friendly error messages in UI

### Never Silently Swallow Errors
- **The default should never be to catch an error and do nothing with it.** Every catch block must make a deliberate, justified decision about what happens next.
- **"Non-blocking" does not mean "invisible."** When an operation is non-blocking (the system can continue without it), the failure must still be surfaced somewhere the relevant audience will see it. Logging alone is not sufficient if no one is actively monitoring logs.
- **Every error needs at least two outlets**: (1) structured logging for backend observability, and (2) a user-facing signal appropriate to the context (UI error state, degraded-state indicator, notification, or at minimum a visual cue that something expected is missing).

### Deciding How to Handle Each Error
Before writing a catch block, evaluate the error along these dimensions:

1. **Who needs to know?**
   - **End users**: If the error affects what they see or can do, they must see an indication — not a blank space where content should be. Show an error state, a fallback message, or a degraded-experience indicator.
   - **Operators/developers**: Always log with enough context to diagnose (error message, stack trace, relevant IDs, what operation was attempted).
   - **Both**: Most errors that affect user-visible features need both.

2. **Should this block the operation?**
   - If the failed operation is the **primary purpose** of the request → the error should propagate (throw or return an error response).
   - If the failed operation is **supplementary/enrichment** (e.g., AI summary on an approval, analytics tracking) → the operation can continue, but the failure must still be recorded and surfaced to the user as a degraded state, not hidden entirely.
   - **When uncertain whether something should be blocking or non-blocking, ask the user.** Do not default to non-blocking just because it's easier to implement.

3. **What does the user see when this fails?**
   - If the answer is "nothing — the section just doesn't render" → this is a silent failure and is **not acceptable**. The user should see either the successful result or a clear indication that the result could not be produced.
   - Design error states into the UI/response from the start. A conditional render like `{data && <Component />}` must always have a corresponding else branch that handles the missing-data case, whether that's an error message, a skeleton, or a "not available" indicator.

4. **Can we persist the failure for later diagnosis?**
   - When a non-blocking operation fails, store enough context (error message, timestamp) alongside the primary record so the failure is visible through normal data access, not only through log diving. This is especially important for async or event-driven operations where the error may not be discovered until much later.

### Anti-Patterns to Avoid
- **Catch-and-continue with no trace**: `catch (e) { /* continue */ }` — always unacceptable.
- **Log-only for user-facing features**: If a feature is missing from the UI because of an error, logging is necessary but not sufficient. The UI must reflect the failure.
- **Blanket "non-blocking" try/catch**: Wrapping an entire operation in try/catch and labeling it "non-blocking" without analyzing whether the user needs to know about the failure.
- **Optional chaining as error hiding**: Using `data?.field && <Component />` to silently skip rendering when data is missing due to an upstream error, rather than showing an error state.

## Bug Fix Verification (CRITICAL)
- **When a bug is reported, do not start by trying to fix it.** Instead, start by writing a test that reproduces the bug. Then, have subagents try to fix the bug and prove it with a passing test.
- **Local compilation and passing tests are necessary but not sufficient to verify a bug fix.** The verification must confirm the bug is actually resolved, not just that the code compiles.
- **When fixing a bug, the verification plan must include:**
  1. **Reproduce**: Confirm the bug exists before the fix (or understand why it occurred from logs/evidence).
  2. **Fix scope**: Search for ALL instances of the broken pattern. A bug in one location often exists in others — `grep` for the broken value, pattern, or logic before declaring the fix complete. Do not fix one instance and assume there are no others.
  3. **Local verification**: Type checks, lint, and tests pass.
  4. **Functional verification**: After deployment, confirm the fix works in the deployed environment. For backend bugs, this means checking logs or API responses. For frontend bugs, this means visually confirming the UI behavior. Do not mark a bug as fixed based solely on local checks.
- **When functional verification isn't possible in the current session** (e.g., requires a deploy the user will do later), explicitly call out what needs to be verified post-deploy and what to look for. Do not silently assume the fix will work.
- **If a bug is being fixed for the second time**, treat it as a red flag. Investigate why the previous fix didn't hold — was the root cause actually addressed, or was only a symptom patched? Document what was different this time.

## Security
- Never log sensitive data (passwords, tokens, PII)
- Always validate and sanitize user input
- Use environment variables for secrets and configuration
- Follow OWASP best practices
