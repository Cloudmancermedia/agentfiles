<!-- EXAMPLE RULE: Python Standards (Personal Profile)
  Profile-specific rules only apply when this profile is active.
  This example covers Python coding standards — style, typing, tooling.
  Replace with your preferred language standards or delete if not needed. -->

# Python Standards

- Follow PEP 8, 4 spaces indentation, 88 char line length (Black default)
- snake_case for variables/functions, PascalCase for classes, UPPER_CASE for constants
- Group imports: stdlib, third-party, local
- Use type hints for function params and return values
- Use specific exception types, avoid bare `except:`
- Use `pytest` for testing
- Use `pathlib` instead of `os.path`
- Use `dataclasses` or `pydantic` for data structures
