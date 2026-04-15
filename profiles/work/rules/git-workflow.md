<!-- EXAMPLE RULE: Git Workflow (Work Profile)
  Profile-specific rules in profiles/<name>/rules/ only apply when that
  profile is active. This is a good place for team conventions that
  differ from your personal projects.

  This example covers branch naming, commit messages, and PR workflow.
  Replace with your team's actual conventions. -->

# Git Workflow

## Branch Naming

Follow conventional commits style with ticket reference:
```
<type>/<ticket>/<short-description>
```

**Examples:**
- `feat/PROJ-33/user-authentication`
- `fix/PROJ-29/dashboard-navigation`
- `chore/PROJ-100/update-dependencies`

**Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`

## Commit Messages

Follow conventional commits format:
```
<type>: <description>

[optional body]

[optional footer with ticket reference]
```

## PR Workflow

1. Create a branch from main following the naming convention above
2. Make changes and test locally
3. Ensure lint, type checking, and tests pass before opening a PR
4. Open a PR with a clear title and description
5. Request review from the appropriate team members
6. Address review feedback
7. Squash and merge after approval

## PR Title Format

Include the ticket number in brackets:
```
[PROJ-33] feat: add user authentication flow
```
