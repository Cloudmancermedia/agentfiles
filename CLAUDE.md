# Project Instructions

## Open Source Safety (CRITICAL)

This is a personal project published as a public GitHub repository. Every commit, file, and piece of content must be treated as publicly visible.

The target is **proprietary and third-party information**, not the owner's own identity. The repository owner's name and their masked GitHub noreply email are fine in commit metadata and in the content — that is their call to make, and it needs no flagging.

**Before every commit, verify that NONE of the following are present:**
- Names, email addresses, or usernames of anyone other than the repository owner
- The owner's real (unmasked) email address — use the GitHub noreply address instead
- Company names, organization names, or employer references
- Internal URLs, tool names, or proprietary process documentation
- AWS account IDs, resource ARNs, or infrastructure details
- API keys, tokens, credentials, or secrets of any kind
- GitHub usernames or organization names belonging to an employer or third party
- Machine hostnames, file paths that reveal system structure, or other PII
- References to specific projects, repositories, or tickets from any employer

**Use these placeholders instead:**
- Emails: `your-work-email@example.com`, `your-personal-email@example.com`
- Companies: generic descriptions ("your team", "your organization")
- Profiles: `sandbox`, `production` (not real AWS profile names)
- Repos: `your-org/your-repo`

This rule applies to all content: code, documentation, comments, commit messages, branch names, and configuration files. When in doubt, generalize — it is better to be too generic than to leak something proprietary. The one thing not to second-guess is the owner's own name.
