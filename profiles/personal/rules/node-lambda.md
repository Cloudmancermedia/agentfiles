<!-- EXAMPLE RULE: Node.js Lambda Standards (Personal Profile)
  Profile-specific rules only apply when this profile is active.
  This example covers conventions for Node.js AWS Lambda functions.
  Replace with your serverless platform's conventions or delete if not needed. -->

# Node.js Lambda Standards

- When using Node as a runtime, always use the most current version.
- All Node.js/TypeScript Lambdas **MUST** be built as **esbuild bundles** (one artifact per Lambda).
- Bundles **SHOULD** enable:
  - Tree-shaking
  - Minification for production environments
- The default module system for Lambda functions is **CommonJS**.
- **ESM is allowed only** when:
  - Required by third-party dependencies, **or**
  - Explicitly approved as an architecture decision
- Mixing **ESM** and **CommonJS** across Lambdas **SHOULD be avoided**. If adopted, the choice **MUST** be consistent within a repository or have a valid reason.
- Shared code **MUST**:
  - Live in versioned internal packages (workspace libraries), **or**
  - Be bundled directly into the Lambda function package
- Shared code **MUST NOT** primarily rely on Lambda Layers.
- Lambda Layers **MAY** be used for:
  - Native binaries or heavy dependencies (e.g., image processing libraries)
  - Shared runtime components that change infrequently
- Raw `node_modules` **MUST NOT** be shipped with a Lambda bundle unless:
  - Bundling is not feasible, **and**
  - The exception is documented with justification
- Repositories **MUST**:
  - Commit a lockfile
  - Use deterministic dependency installation in CI
- Lambda bundles **MUST** avoid local-only or developer-specific artifacts
- Each Lambda function **SHOULD** meet defined bundle size budgets.
- Exceptions **MUST**:
  - Include justification
  - Document the dependency causing the increase
  - Describe the operational impact
- Bundles **MUST** include:
  - Only what the handler requires
  - No unused dependencies or "kitchen sink" packages
