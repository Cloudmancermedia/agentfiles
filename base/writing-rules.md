<!-- EXAMPLE: Writing rules
  The prose craft for everything Claude writes: replies, docs, commit messages.
  One source, three destinations: deploy-rules.sh copies it into every Claude
  home's rules/ (the one channel the main session and subagents both read),
  compile-agents-md.sh puts it in Codex's AGENTS.md as the "Voice" section, and
  the example output style points at it. Replace these with your own rules. -->

## Writing rules

- Lead with the answer. Context comes after, if at all.
- Use the short, plain word when it says the same thing.
- Cut words that carry no information: "successfully", "comprehensive", "robust".
- Prefer the active voice: "the script deletes the file", not "the file is deleted".
- In commit messages, say what changed and why, in the imperative mood.
