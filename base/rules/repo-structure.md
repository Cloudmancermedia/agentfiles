<!-- EXAMPLE RULE: Repository Structure
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example establishes conventions for directory layout, README
  requirements, and the principle that structure should communicate intent. -->

# Repository Structure Conventions

Repository structure should prioritize **discoverability**, **clarity**, and **safe change**. The goal is to help a new reader quickly understand what the repository contains and where to look — not to enforce a rigid or framework-specific layout.

## Required
Every repository **MUST** include:
- A `README.md` at the root of the repository
- A clearly identifiable location for primary source or runtime code
- A discoverable location for documentation or design context (folder or README references)

## Recommended (When Applicable)
Repositories **SHOULD** use the following conventions when they add value to the project:
- `src/` — Primary runtime or library code
- `docs/` — Architecture notes, ADRs, diagrams, and design documentation
- `scripts/` — One-off scripts, automation, or developer tooling
- `tests/` or `__tests__/` — Test code

Not all repositories require all directories. Small or simple projects may collapse structure where appropriate.

## Guiding Principles
- Structure should communicate **intent**, not framework or implementation details
- Top-level directories should have an obvious purpose based on their name
- If a directory's purpose is non-obvious, it **MUST** be explained in `README.md`
- Repository structure may vary based on project type:
  - Libraries optimize for API clarity
  - Applications optimize for runtime boundaries
  - Infrastructure projects optimize for environment and stack separation
- Uniformity is less important than clarity and maintainability

## README Expectations
The `README.md` **MUST** answer the following questions:
1. What is this repository?
2. How do I run, build, or use it?
3. Where does the primary code live?
4. Where can I find documentation or design context?

The README should be concise and practical. Extensive documentation may live elsewhere.
