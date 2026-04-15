<!-- EXAMPLE RULE: Documentation Standards
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers when to write comments, where to keep docs, and the
  principle that documentation should add value, not noise. -->

# Documentation Standards

- Add comments only for complex business logic.
- Avoid obvious, mundane, superfluous, general comments that do nothing to help a user to understand the code or just repeat what the code does.
- Keep the root README file up to date with a brief overview of the project and clear setup instructions.
- Always keep documentation outside of the README file in the `docs` folder.
- Like comments, documentation should always add value to a developer reading them. Never create documentation like reports, breakdowns, or details about short lived implementations, updates, or explanations that do not add to the codebase in some way unless it is absolutely necessary to complete a specific task. Once the task is complete, this temporary documentation should be cleaned up and deleted.
- When it comes to any kind of documentation, always be consolidating. Documentation should always be created in mind with helping a developer understand the codebase and should always be kept clear, focused, and helpful. Always be checking the documentation to ensure that information is not repeated.
- Documentation other than the root `README` should follow a dashed file naming convention with a clear and concise description of its purpose. `local-development` or `deployment`.
